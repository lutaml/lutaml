# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "stringio"
require "json"
require "lutaml/lml/cli"

RSpec.describe "language version negotiation" do
  def parse(source)
    Lutaml::Lml.parse_document(source)
  end

  def canonical(source)
    Lutaml::Formatter::Canonical.new(parse(source)).render
  end

  it "records the declared version on the document" do
    expect(parse("lml \"1.0\"\nclass A { }\n").lml_version).to eq("1.0")
  end

  it "accepts a document without a prologue" do
    document = parse("class A { }\n")

    expect(document.lml_version).to be_nil
    expect(document.classes.map(&:name)).to eq(["A"])
  end

  it "renders the prologue first in canonical form" do
    source = "require \"base.lml\"\nclass A { }\n"
    output = canonical("lml \"1.0\"\n#{source}")

    expect(output).to start_with("lml \"1.0\"\n\nrequire \"base.lml\"")
    expect(canonical(output)).to eq(output)
  end

  it "warns, with a position, when the document declares a newer version" do
    diagnostics = Lutaml::Lml::Validator.diagnostics(
      parse("lml \"9.9\"\nclass A { }\n"),
    )

    expect(diagnostics.map(&:code)).to eq(["contract/LML-C06"])
    expect(diagnostics.first.severity).to eq("warning")
    expect(diagnostics.first.line).to eq(1)
    expect(diagnostics.first.column).to eq(6)
    expect(diagnostics.first.message).to include("9.9", Lutaml::Lml::Grammar.version)
  end

  it "does not warn for the supported version" do
    diagnostics = Lutaml::Lml::Validator.diagnostics(
      parse("lml \"#{Lutaml::Lml::Grammar.version}\"\nclass A { }\n"),
    )

    expect(diagnostics).to be_empty
  end

  describe "CLI validate" do
    def run_validate(*args)
      output = StringIO.new
      original = $stdout
      $stdout = output
      begin
        Lutaml::Cli::LmlCommands.start(["validate", *args])
      rescue SystemExit => e
        return [output.string, e.status]
      ensure
        $stdout = original
      end
      [output.string, 0]
    end

    it "exits zero when the only diagnostic is a version warning" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "future.lml")
        File.write(path, "lml \"9.9\"\nclass A { }\n")
        output, status = run_validate(path)

        expect(status).to eq(0)
        expect(output).to include("contract/LML-C06")
        expect(output).to include("warning")
      end
    end

    it "reports the warning in JSON with warning severity" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "future.lml")
        File.write(path, "lml \"9.9\"\nclass A { }\n")
        output, status = run_validate(path, "--format", "json")

        expect(status).to eq(0)
        expect(JSON.parse(output).first).to include(
          "code" => "contract/LML-C06",
          "severity" => "warning",
        )
      end
    end
  end
end
