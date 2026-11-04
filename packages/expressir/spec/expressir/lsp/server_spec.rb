# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "json"
require "stringio"

ALPHA = <<~EXPRESS
  SCHEMA alpha;
  ENTITY point;
    x : REAL;
    y : REAL;
  END_ENTITY;
  TYPE colour = ENUMERATION OF (red, green);
  END_TYPE;
  END_SCHEMA;
EXPRESS

BETA = <<~EXPRESS
  SCHEMA beta;
  USE FROM alpha (point, colour AS hue);
  ENTITY shape;
    origin : point;
    tint : hue;
  END_ENTITY;
  END_SCHEMA;
EXPRESS

RSpec.describe Expressir::Lsp::Server do
  def frame(message)
    json = JSON.generate(message)
    "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
  end

  def run_session(messages)
    input = StringIO.new(messages.map { |message| frame(message) }.join)
    output = StringIO.new
    status = described_class.new(input: input, output: output).run
    [status, responses(output)]
  end

  def responses(output)
    output.rewind
    messages = []
    while (header = output.gets)
      next unless header.start_with?("Content-Length:")

      output.gets
      length = header.split(":", 2).last.to_i
      messages << JSON.parse(output.read(length))
    end
    messages
  end

  def open(uri, text)
    { "jsonrpc" => "2.0", "method" => "textDocument/didOpen",
      "params" => { "textDocument" => { "uri" => uri, "languageId" => "express",
                                        "version" => 1, "text" => text } } }
  end

  def request(id, method, params)
    { "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }
  end

  def position_of(text, token, occurrence: 0)
    index = -1
    (occurrence + 1).times { index = text.index(token, index + 1) }
    line = text[0...index].count("\n")
    line_start = text[0...index].rindex("\n")
    line_start = line_start ? line_start + 1 : 0
    { "line" => line, "character" => index - line_start }
  end

  def apply_changes(text, edits)
    edits.sort_by { |edit| -edit["range"]["start"]["line"] }.reduce(text) do |result, edit|
      start_position = edit["range"]["start"]
      end_position = edit["range"]["end"]
      start_byte = offset_at(result, start_position)
      end_byte = offset_at(result, end_position)
      result[0...start_byte] + edit["newText"] + result[end_byte..]
    end
  end

  def offset_at(text, position)
    line_start = 0
    position["line"].times { line_start = text.index("\n", line_start) + 1 }
    line_start + position["character"]
  end

  it "advertises LSP 3.17 capabilities and exits cleanly" do
    status, messages = run_session([
                                     request(1, "initialize", {}),
                                     request(2, "shutdown", {}),
                                     { "jsonrpc" => "2.0", "method" => "exit" },
                                   ])
    expect(status).to eq(0)
    initialize_result = messages.find { |message| message["id"] == 1 }["result"]
    expect(initialize_result["capabilities"]).to include(
      "positionEncoding" => "utf-16",
      "definitionProvider" => true,
      "referencesProvider" => true,
      "hoverProvider" => true,
      "documentSymbolProvider" => true,
    )
    expect(initialize_result["serverInfo"]["name"]).to eq("expressir-lsp")
  end

  it "publishes diagnostics on open and clears resolvable cross-document notes" do
    _status, messages = run_session([
                                      open("file:///alpha.exp", ALPHA),
                                      open("file:///beta.exp", BETA),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    diagnostics = messages.select do |message|
      message["method"] == "textDocument/publishDiagnostics"
    end
    expect(diagnostics.map { |message| message["params"]["diagnostics"] })
      .to eq([[], []])
  end

  it "reports parse errors with a range" do
    broken = "SCHEMA broken;\nENTITY thing\nEND_SCHEMA;\n"
    _status, messages = run_session([
                                      open("file:///broken.exp", broken),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    diagnostic = messages.find do |message|
      message["method"] == "textDocument/publishDiagnostics"
    end["params"]["diagnostics"].first
    expect(diagnostic["severity"]).to eq(1)
    expect(diagnostic["range"]["start"]["line"]).to be >= 0
  end

  it "returns document symbols" do
    _status, messages = run_session([
                                      open("file:///alpha.exp", ALPHA),
                                      request(2, "textDocument/documentSymbol",
                                              { "textDocument" => { "uri" => "file:///alpha.exp" } }),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    symbols = messages.find { |message| message["id"] == 2 }["result"]
    expect(symbols.map { |symbol| symbol["name"] })
      .to include("alpha", "point", "colour")
  end

  it "navigates a USE ladder and its alias map" do
    beta_position = position_of(BETA, "origin : point")
    beta_position["character"] += "origin : ".length
    _status, messages = run_session([
                                      open("file:///alpha.exp", ALPHA),
                                      open("file:///beta.exp", BETA),
                                      request(2, "textDocument/definition",
                                              { "textDocument" => { "uri" => "file:///beta.exp" },
                                                "position" => beta_position }),
                                      request(3, "textDocument/definition",
                                              { "textDocument" => { "uri" => "file:///beta.exp" },
                                                "position" => position_of(BETA, "tint : hue")
                                                  .merge("character" => 9) }),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    point_definition = messages.find { |message| message["id"] == 2 }["result"]
    expect(point_definition["uri"]).to eq("file:///alpha.exp")
    expect(point_definition["range"]["start"]["line"]).to eq(1)

    hue_definition = messages.find { |message| message["id"] == 3 }["result"]
    expect(hue_definition["uri"]).to eq("file:///alpha.exp")
    expect(hue_definition["range"]["start"]["line"]).to eq(5)
  end

  it "lists references across schemas" do
    _status, messages = run_session([
                                      open("file:///alpha.exp", ALPHA),
                                      open("file:///beta.exp", BETA),
                                      request(2, "textDocument/references",
                                              { "textDocument" => { "uri" => "file:///alpha.exp" },
                                                "position" => position_of(ALPHA, "point"),
                                                "context" => { "includeDeclaration" => true } }),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    references = messages.find { |message| message["id"] == 2 }["result"]
    uri_lines = references.map { |location| [location["uri"], location["range"]["start"]["line"]] }
    expect(uri_lines).to include(["file:///alpha.exp", 1],
                                 ["file:///beta.exp", 1],
                                 ["file:///beta.exp", 3])
  end

  it "hovers a declaration through the pretty formatter" do
    _status, messages = run_session([
                                      open("file:///alpha.exp", ALPHA),
                                      request(2, "textDocument/hover",
                                              { "textDocument" => { "uri" => "file:///alpha.exp" },
                                                "position" => position_of(ALPHA, "point") }),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    contents = messages.find { |message| message["id"] == 2 }["result"]["contents"]
    expect(contents["kind"]).to eq("markdown")
    expect(contents["value"]).to include("ENTITY point")
  end

  it "renames a declaration across two schemas and keeps both parseable" do
    _status, messages = run_session([
                                      open("file:///alpha.exp", ALPHA),
                                      open("file:///beta.exp", BETA),
                                      request(2, "textDocument/rename",
                                              { "textDocument" => { "uri" => "file:///alpha.exp" },
                                                "position" => position_of(ALPHA, "point"),
                                                "newName" => "location" }),
                                      { "jsonrpc" => "2.0", "method" => "exit" },
                                    ])
    changes = messages.find { |message| message["id"] == 2 }["result"]["changes"]
    renamed_alpha = apply_changes(ALPHA, changes.fetch("file:///alpha.exp"))
    renamed_beta = apply_changes(BETA, changes.fetch("file:///beta.exp"))

    expect(renamed_alpha).to include("ENTITY location;")
    expect(renamed_beta).to include("USE FROM alpha (location, colour AS hue);")
    expect(renamed_beta).to include("origin : location;")
    expect(renamed_beta).to include("tint : hue;")

    original = Expressir::Express::Parser.from_exp(ALPHA, include_source: true)
    revised = Expressir::Express::Parser.from_exp(renamed_alpha, include_source: true)
    deltas = Expressir::Express::SchemaCompare.compare(original.schemas.first,
                                                       revised.schemas.first)
    expect(deltas.map(&:path)).to include("alpha.point", "alpha.location")
    expect(deltas.map(&:op)).to include(:removed, :added)
    expect { Expressir::Express::Parser.from_exp(renamed_beta) }.not_to raise_error
    expect { Expressir::Express::Formatter.format(revised.schemas.first) }
      .not_to raise_error
  end
end
