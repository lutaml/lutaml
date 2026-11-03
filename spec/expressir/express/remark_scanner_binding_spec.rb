# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::RemarkScanner do
  # Runs only when the native extension is built; the same sources with
  # recorded expectations double as the native-vs-Ruby parity check,
  # since the expectations were pinned by the pure-Ruby scanner suite
  # (remark_scanner_spec.rb), which exercises the fallback lane in CI.
  let(:native) { Expressir::Express::Core::NATIVE_AVAILABLE }

  it "delegates to the native scanner when the extension is built" do
    skip "expressir core extension not compiled" unless native

    remarks = described_class.new("-- hello world\n(* doc *)\n").scan
    expect(remarks.map(&:class).uniq).to eq([described_class::Remark])

    tail, embedded = remarks
    expect(tail.position).to eq(0)
    expect(tail.end_position).to eq(14)
    expect(tail.line).to eq(1)
    expect(tail.text).to eq("hello world")
    expect(tail.tag).to be_nil
    expect(tail.format).to eq("tail")
    expect(embedded.format).to eq("embedded")
    expect(embedded.text).to eq("doc")
  end

  it "reproduces the Ruby scanner's tagged-remark expectations" do
    skip "expressir core extension not compiled" unless native

    tagged = described_class.new("--\"schema_x.attr\" tagged tail remark\n").scan.first
    expect(tagged.tag).to eq("schema_x.attr")
    expect(tagged.text).to eq("tagged tail remark")

    ip = described_class.new("-- IP1: an informal proposition\n").scan.first
    expect(ip.tag).to eq("IP1")
    expect(ip.text).to eq("an informal proposition")

    inline_dash = described_class.new('(*"s" body -- with dash *)').scan.first
    expect(inline_dash.tag).to eq("s")
    expect(inline_dash.text).to eq("body -- with dash")
  end

  it "reproduces the Ruby scanner's nesting and overlap expectations" do
    skip "expressir core extension not compiled" unless native

    nested = described_class.new("(* a (* b (* c *) b *) a *)").scan
    expect(nested.map(&:format)).to eq(["embedded"])
    expect(nested.first.text).to eq("a (* b (* c *) b *) a")

    overlap = described_class.new("(*)").scan
    expect(overlap.first.text).to eq("")
    expect(overlap.first.position).to eq(0)
    expect(overlap.first.end_position).to eq(4)
  end

  it "reproduces the Ruby scanner's string and CRLF expectations" do
    skip "expressir core extension not compiled" unless native

    expect(described_class.new("x : STRING := 'it''s -- ok';\n").scan).to eq([])
    expect(described_class.new("x := 'never closed -- not a tail").scan).to eq([])

    tail = described_class.new("CODE; -- tail remark\r\nnext line\n").scan.first
    expect(tail.text).to eq("tail remark")
  end

  it "preserves multibyte remark text with byte positions" do
    skip "expressir core extension not compiled" unless native

    source = "name : STRING; -- Name in Japanese: 名前\n"
    remark = described_class.new(source).scan.first
    expect(remark.text).to eq("Name in Japanese: 名前")
    expect(remark.text.encoding).to eq(Encoding::UTF_8)
    expect(remark.position).to eq(source.b.index("--"))
  end
end
