# frozen_string_literal: true

require "spec_helper"
require "expressir"

RSpec.describe Expressir::Lsp::Document do
  subject(:document) do
    described_class.new(uri: "file:///demo.exp", text: source)
  end

  let(:source) do
    <<~EXPRESS
      SCHEMA demo;
      ENTITY point;
        x : REAL;
        y : REAL;

      END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  describe "#position and #byte_offset" do
    it "round-trips byte offsets through UTF-16 positions" do
      offset = source.index("point")
      position = document.position(offset)
      expect(position).to eq("line" => 1, "character" => 7)
      expect(document.byte_offset(1, 7)).to eq(offset)
    end

    it "counts astral characters as two UTF-16 units" do
      text = "SCHEMA demo;\n-- \u{1F600}\nENTITY point;\nEND_ENTITY;\nEND_SCHEMA;\n"
      document = described_class.new(uri: "file:///emoji.exp", text: text)
      position = document.position(text.b.index("ENTITY"))
      expect(position).to eq("line" => 2, "character" => 0)
    end
  end

  describe "#token_at" do
    it "returns the identifier under the cursor" do
      position = document.position(source.index("point"))
      token = document.token_at(position)
      expect(token.text).to eq("point")
      expect(token.start_byte).to eq(source.index("point"))
    end

    it "returns nil on a blank line and reads adjacent tokens" do
      expect(document.token_at("line" => 4, "character" => 0)).to be_nil
      expect(document.token_at("line" => 0, "character" => 7).text).to eq("demo")
    end
  end

  describe "#symbols" do
    it "lists declarations with kind and name ranges" do
      symbols = document.symbols
      expect(symbols.map { |symbol| symbol["name"] })
        .to include("demo", "point", "x", "y")
      point = symbols.find { |symbol| symbol["name"] == "point" }
      expect(point["kind"]).to eq(5)
      expect(point["selectionRange"]["start"]).to eq("line" => 1,
                                                     "character" => 7)
    end
  end

  describe "parse failures" do
    it "records the error and keeps the last good tree" do
      document.update("SCHEMA demo;\nENTITY point\nEND_SCHEMA;\n")
      expect(document.parse_error).not_to be_nil
      expect(document.schemas.map(&:id)).to eq(["demo"])
    end
  end
end
