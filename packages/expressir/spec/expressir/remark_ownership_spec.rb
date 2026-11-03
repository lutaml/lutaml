# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::RemarkOwnership do
  def entry(path, text, format: "tail", tagged: false, placement: nil,
            region: nil)
    Expressir::RemarkOwnership::Trace::Entry.new(
      path: path, text: text, format: format, tagged: tagged,
      placement: placement, region: region
    )
  end

  def at(path, placement: nil, region: nil, count: 1)
    { [path, placement, region] => count }
  end

  describe ".moved" do
    it "reports nothing when a remark stays put" do
      expect(described_class.moved([entry("A/B", "hello")],
                                   [entry("A/B", "hello")])).to be_empty
    end

    it "reports a remark that changed owner" do
      moved = described_class.moved([entry("A/B", "hello")],
                                    [entry("A", "hello")])

      expect(moved).to eq({ ["hello", "tail", false] => [at("A/B"), at("A")] })
    end

    it "reports a remark that kept its owner but changed placement" do
      before = [entry("A", "hi", placement: "leading")]
      after = [entry("A", "hi", placement: "trailing", region: "statements")]

      expect(described_class.moved(before, after).keys).to eq([["hi", "tail", false]])
    end

    it "tells apart a tail and an embedded remark of the same text" do
      before = [entry("A", "same", format: "tail"),
                entry("B", "same", format: "embedded")]
      after = [entry("B", "same", format: "tail"),
               entry("A", "same", format: "embedded")]

      expect(described_class.moved(before, after).keys)
        .to contain_exactly(["same", "tail", false],
                            ["same", "embedded", false])
    end

    it "ignores a remark that only one side has" do
      expect(described_class.moved([entry("A", "gone")], [entry("A", "new")]))
        .to be_empty
    end

    # Placement is nil for some remarks and a string for others. Sorting the
    # place tuples rather than counting them raises on that mix.
    it "does not raise when placements differ under one path" do
      before = [entry("A", "x", placement: "leading"), entry("A", "x")]
      after = [entry("A", "x"), entry("A", "x", placement: "trailing")]

      expect(described_class.moved(before, after).keys)
        .to eq([["x", "tail", false]])
    end

    it "reports a change in how many copies sit on one owner" do
      before = [entry("A", "x"), entry("A", "x")]
      after = [entry("A", "x")]

      expect(described_class.moved(before, after).keys).to eq([["x", "tail", false]])
    end
  end

  describe ".schema_escape?" do
    it "accepts a schema level remark written outside its SCHEMA" do
      move = [at("ExpFile/schemas[0]Declarations::Schema(s)"), at("ExpFile")]

      expect(described_class.schema_escape?(move)).to be(true)
    end

    # Both shapes below are what main actually does to
    # `function_body_remarks.exp`: a remark inside a REPEAT loop reattaches
    # outside it. Neither may ever be waved through as a known gap.
    it "rejects a remark escaping a REPEAT to its enclosing statement" do
      base = "ExpFile/schemas[0]Declarations::Schema(s)/" \
             "functions[0]Declarations::Function(f)/statements[0]Statements::If"
      move = [at("#{base}/statements[0]Statements::Repeat(i)"), at(base)]

      expect(described_class.schema_escape?(move)).to be(false)
    end

    it "rejects a remark escaping a REPEAT to its enclosing function" do
      base = "ExpFile/schemas[0]Declarations::Schema(s)/" \
             "functions[0]Declarations::Function(f)"
      move = [at("#{base}/statements[0]Statements::Repeat(i)"), at(base)]

      expect(described_class.schema_escape?(move)).to be(false)
    end

    # SchemaVersion shares the Schema prefix, so a prefix test would wave a
    # move off it through as a schema escape.
    it "rejects a move off a SchemaVersion" do
      move = [at("ExpFile/schemas[0]Declarations::SchemaVersion(v)"),
              at("ExpFile")]

      expect(described_class.schema_escape?(move)).to be(false)
    end

    it "rejects a move that lands somewhere other than the file" do
      move = [at("ExpFile/schemas[0]Declarations::Schema(s)"),
              at("ExpFile/schemas[1]Declarations::Schema(other)")]

      expect(described_class.schema_escape?(move)).to be(false)
    end

    it "rejects a schema level move that also changed placement" do
      move = [at("ExpFile/schemas[0]Declarations::Schema(s)"),
              at("ExpFile", placement: "leading")]

      expect(described_class.schema_escape?(move)).to be(false)
    end

    # One copy of a repeated text escapes while another stays put. Judging
    # every place rather than only the ones that changed would call this a bug.
    it "accepts one copy escaping while another stays where it was" do
      kept = ["ExpFile/schemas[0]Declarations::Schema(s)/" \
              "functions[0]Declarations::Function(f)/" \
              "statements[0]Statements::Return", nil, nil]
      move = [{ ["ExpFile/schemas[0]Declarations::Schema(s)", nil, nil] => 1,
                kept => 1 },
              { ["ExpFile", nil, nil] => 1, kept => 1 }]

      expect(described_class.schema_escape?(move)).to be(true)
    end

    it "rejects a move where nothing actually departed" do
      place = at("ExpFile/schemas[0]Declarations::Schema(s)")

      expect(described_class.schema_escape?([place, place])).to be(false)
    end

    it "rejects a move where more arrived than departed" do
      move = [at("ExpFile/schemas[0]Declarations::Schema(s)"),
              at("ExpFile", count: 2)]

      expect(described_class.schema_escape?(move)).to be(false)
    end
  end

  describe "Trace tagged remark handling" do
    # `remarks` holds a mirror of every untagged text as well as the genuinely
    # tagged ones, so reading it raw counts each untagged remark twice.
    it "does not count a mirrored untagged text as a tagged remark" do
      model = Expressir::Express::Parser.from_file(
        "spec/fixtures/function_body_remarks.exp",
      )

      traced = Expressir::RemarkOwnership::Trace.of(model)

      expect(traced.count(&:tagged)).to eq(0)
      expect(traced).not_to be_empty
    end

    it "traces the tagged remarks of a fixture that has only tagged ones" do
      model = Expressir::Express::Parser.from_file("spec/syntax/remark.exp")

      traced = Expressir::RemarkOwnership::Trace.of(model)

      expect(traced.count(&:tagged)).to eq(traced.size)
      expect(traced.size).to be >= 134
    end
  end
end
