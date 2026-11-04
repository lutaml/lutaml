# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "expressir/eval"

# TODO.compat/07: the evaluator conformance matrix — every ISO
# 10303-11 clause 15 standard function cited per clause with its
# coverage status, and every implemented function mutation-tested
# against its clause example (the expected result and a deliberately
# wrong value must be distinguished, or the suite fails).
RSpec.describe Expressir::Eval::BuiltinMatrix do
  let(:schema) do
    Expressir::Express::Parser.from_exp("SCHEMA m; END_SCHEMA;").schemas.first
  end
  let(:interpreter) { Expressir::Eval::Interpreter.new(schema: schema) }

  # Per-function clause examples: [arguments, expected, mutation].
  # The mutation is a deliberately wrong result the examples must
  # refute — a function whose implementation drifts to the mutation
  # value fails the suite here.

  it "cites every row with a clause and a known status" do
    described_class::ROWS.each do |row|
      expect(row.clause).to match(/\A15\.\d+/)
      expect(row.status)
        .to eq(described_class::IMPLEMENTED).or eq(described_class::DIVERGENT)
    end
  end

  it "covers the clause 15 function inventory" do
    names = described_class::ROWS.map(&:name)
    %w[ABS ACOS ASIN ATAN BLENGTH BOUNDS COS EXISTS EXP FORMAT HIBOUND
       HIINDEX LENGTH LOBOUND LOINDEX LOG LOG2 LOG10 NVL ODD ROLESOF SIN
       SIZEOF SQRT TAN TYPEOF USEDIN VALUE VALUE_IN VALUE_UA].each do |name|
      expect(names).to include(name), "clause 15 function #{name} missing"
    end
  end

  it "marks only implemented rows dispatchable, divergent rows rejected" do
    described_class::ROWS.each do |row|
      if row.status == described_class::IMPLEMENTED
        expect { interpreter.call(row.name, MATRIX_EXAMPLES.fetch(row.name)[0]) }
          .not_to raise_error
      else
        expect { interpreter.call(row.name, []) }
          .to raise_error(Expressir::Eval::Error, /not implemented/)
      end
    end
  end

  it "mutation-tests every implemented function against its clause example" do
    described_class::ROWS.each do |row|
      next unless row.status == described_class::IMPLEMENTED

      arguments, expected, mutation = MATRIX_EXAMPLES.fetch(row.name)
      result = interpreter.call(row.name, arguments)

      expect(result).to eq(expected),
                        "#{row.name} (#{row.clause}) drifted from its clause example"
      expect(result).not_to eq(mutation),
                            "#{row.name}: the mutation survives — the example no longer " \
                            "distinguishes a broken implementation"
    end
  end

  it "generates the matrix deterministically" do
    generations = Array.new(2) { described_class.to_adoc }
    expect(generations.uniq.size).to eq(1)
    expect(described_class.to_adoc).to include("ISO 10303-11 clause 15")
    described_class::ROWS.each do |row|
      expect(described_class.to_adoc).to include("`#{row.name}`")
      expect(described_class.to_adoc).to include(row.clause)
    end
  end
end

MATRIX_EXAMPLES = {
  "ABS" => [[-3], 3, -3],
  "ACOS" => [[1.0], 0.0, 1.0],
  "ASIN" => [[0.0], 0.0, 1.0],
  "ATAN" => [[1.0], Math::PI / 4, 0.0],
  "ATAN2" => [[1.0, 1.0], Math::PI / 4, 0.0],
  "BLENGTH" => [[Expressir::Eval::Values::Binary.new(bits: "10")], 2, 0],
  "BOUNDS" => [[Expressir::Eval::Values::Aggregate.of(:list, [7, 8, 9, 10])],
               Expressir::Eval::Values::Aggregate.of(:list, [1, 4]),
               Expressir::Eval::Values::Aggregate.of(:list, [0, 3])],
  "COS" => [[0.0], 1.0, 0.0],
  "EXISTS" => [[5], Expressir::Eval::Values::Logical.new(value: Expressir::Eval::Values::LOGICAL_TRUE),
               Expressir::Eval::Values::Logical.new(value: Expressir::Eval::Values::LOGICAL_FALSE)],
  "EXP" => [[0.0], 1.0, 0.0],
  "HIBOUND" => [[Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])], 3, 0],
  "HIINDEX" => [[Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])], 3, 0],
  "LENGTH" => [["abc"], 3, 0],
  "LOBOUND" => [[Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])], 1, 0],
  "LOINDEX" => [[Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])], 1, 0],
  "LOG" => [[Math::E], 1.0, 0.0],
  "LOG2" => [[8.0], 3.0, 0.0],
  "LOG10" => [[100.0], 2.0, 0.0],
  "NVL" => [[Expressir::Eval::Values::INDETERMINATE, 7], 7,
            Expressir::Eval::Values::INDETERMINATE],
  "ODD" => [[3], Expressir::Eval::Values::Logical.new(value: Expressir::Eval::Values::LOGICAL_TRUE),
            Expressir::Eval::Values::Logical.new(value: Expressir::Eval::Values::LOGICAL_FALSE)],
  "ROLESOF" => [[5], Expressir::Eval::Values::Aggregate.of(:set, []),
                Expressir::Eval::Values::Aggregate.of(:set, ["x"])],
  "SIN" => [[0.0], 0.0, 1.0],
  "SIZEOF" => [[Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])], 3, 0],
  "SQRT" => [[9.0], 3.0, 2.0],
  "TAN" => [[0.0], 0.0, 1.0],
  "TYPEOF" => [[Expressir::Eval::Values::Instance.new(
    id: 1,
    record: Expressir::P21::Record.new(keyword: "thing"),
  )],
               Expressir::Eval::Values::Aggregate.of(:set, ["THING"]),
               Expressir::Eval::Values::Aggregate.of(:set, [])],
  "USEDIN" => [[nil, nil], Expressir::Eval::Values::Aggregate.of(:bag, []),
               Expressir::Eval::Values::Aggregate.of(:bag, ["x"])],
  "VALUE" => [["42"], 42, "42"],
  "VALUE_IN" => [[2, Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])],
                 Expressir::Eval::Values::Logical.new(value: Expressir::Eval::Values::LOGICAL_TRUE),
                 Expressir::Eval::Values::Logical.new(value: Expressir::Eval::Values::LOGICAL_FALSE)],
}.freeze
