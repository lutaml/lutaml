# frozen_string_literal: true

require "spec_helper"

# expressir#373: the native parse path corrupted small schemas — a token
# slice (e.g. the schema id) swallowed tens of bytes past its end at
# certain byte sizes (~<70B, non-monotonic). Fixed by parsanol's tree
# parity / EOF scan work (parsanol-ruby 1.3.45, parsanol-rs 0.8.2);
# these examples pin the window so a parser regression surfaces here.
RSpec.describe Expressir::Express::Parser do # small-input parse integrity (expressir#373)
  {
    "single-line entity" =>
      ["SCHEMA a;\nENTITY e; x : STRING; END_ENTITY;\nEND_SCHEMA;\n", %w[e]],
    "single-line entity, attr last" =>
      ["SCHEMA a;\nENTITY e; x : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n", %w[e]],
    "attribute referencing USE" =>
      ["SCHEMA a;\nUSE FROM b (c);\nENTITY e; x : c;\nEND_ENTITY;\nEND_SCHEMA;\n", %w[e]],
    "interface only" =>
      ["SCHEMA a;\nUSE FROM b (c);\nEND_SCHEMA;\n", []],
    "schema only" =>
      ["SCHEMA a;\nEND_SCHEMA;\n", []],
  }.each do |label, (src, expected_entities)|
    it "parses #{label} (#{src.bytesize}B) without token overrun" do
      exp = described_class.from_exp(src, skip_references: true)
      schema = exp.schemas.first
      expect(schema.id).to eq("a")
      expect(schema.entities.map(&:id)).to eq(expected_entities)
    end
  end

  it "keeps every byte size in the reported window clean" do
    results = (22..120).step(7).map do |n|
      pad = " " * [n - 30, 0].max
      src = "SCHEMA a;\nUSE FROM b (c);#{pad}\nEND_SCHEMA;\n"
      described_class.from_exp(src, skip_references: true)
        .schemas.first.id
    rescue StandardError
      nil
    end
    expect(results.uniq).to eq(%w[a])
  end
end
