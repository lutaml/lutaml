# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "expressir/eval"

# TODO.sota/02 step 1: pure expression evaluation per ISO 10303-11
# ch.12 (TODO.sota/01 clause map carries the operator domains).
RSpec.describe Expressir::Eval::Expression do
  let(:env) { Expressir::Eval::Environment.new(schema: nil) }

  def evaluate(expression_source)
    repository = Expressir::Express::Parser.from_exp(
      "SCHEMA eval_probe;\nCONSTANT\n  probe_c : INTEGER := #{expression_source};\nEND_CONSTANT;\nEND_SCHEMA;\n",
    )
    described_class.evaluate(repository.schemas.first.constants.first.expression, env)
  end

  shared_examples "evaluates to" do |expected|
    it "evaluates to #{expected.inspect}" do
      expect(evaluate(expected.delete(:src))).to eq(expected.fetch(:value))
    end
  end

  describe "arithmetic (12.1)" do
    it_behaves_like "evaluates to", src: "1 + 2", value: 3
    it_behaves_like "evaluates to", src: "1.5 + 1", value: 2.5
    it_behaves_like "evaluates to", src: "7 / 2", value: 3.5
    it_behaves_like "evaluates to", src: "7 div 2", value: 3
    it_behaves_like "evaluates to", src: "7.9 div 2", value: 3
    it_behaves_like "evaluates to", src: "2 ** 3", value: 8
    it_behaves_like "evaluates to", src: "2.0 ** 3", value: 8.0
    it_behaves_like "evaluates to", src: "-3 + 1", value: -2
  end

  describe "logical operators (12.4)" do
    it_behaves_like "evaluates to", src: "TRUE AND FALSE", value: Expressir::Eval::Values::Logical.false_value
    it_behaves_like "evaluates to", src: "TRUE OR FALSE", value: Expressir::Eval::Values::Logical.true_value
    it_behaves_like "evaluates to", src: "TRUE XOR TRUE", value: Expressir::Eval::Values::Logical.false_value
    it_behaves_like "evaluates to", src: "NOT TRUE", value: Expressir::Eval::Values::Logical.false_value
    it_behaves_like "evaluates to", src: "NOT FALSE", value: Expressir::Eval::Values::Logical.true_value
  end

  describe "relational (12.2)" do
    it_behaves_like "evaluates to", src: "(1 < 2) AND (2 <= 2)",
                                    value: Expressir::Eval::Values::Logical.true_value
    it_behaves_like "evaluates to", src: "'abc' < 'abd'",
                                    value: Expressir::Eval::Values::Logical.true_value
    it_behaves_like "evaluates to", src: "3 IN [1, 2, 3]",
                                    value: Expressir::Eval::Values::Logical.true_value
    it_behaves_like "evaluates to", src: "9 IN [1, 2, 3]",
                                    value: Expressir::Eval::Values::Logical.false_value
    it_behaves_like "evaluates to", src: "'ab' LIKE 'a*'",
                                    value: Expressir::Eval::Values::Logical.true_value
    it_behaves_like "evaluates to", src: "'a1' LIKE 'a#'",
                                    value: Expressir::Eval::Values::Logical.true_value
    it_behaves_like "evaluates to", src: "'aB' LIKE 'a^'",
                                    value: Expressir::Eval::Values::Logical.true_value
  end

  describe "aggregates (12.6)" do
    it_behaves_like "evaluates to", src: "[1, 2] + [3]",
                                    value: Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3])
    it_behaves_like "evaluates to", src: "0 + [1, 2]",
                                    value: Expressir::Eval::Values::Aggregate.of(:list, [0, 1, 2])
    it "removes elements from a SET per table 18" do
      repository = Expressir::Express::Parser.from_exp(<<~EXPRESS)
        SCHEMA eval_probe;
          FUNCTION f(s : SET OF INTEGER) : SET OF INTEGER;
            RETURN (s - 1);
          END_FUNCTION;
        END_SCHEMA;
      EXPRESS
      function = repository.schemas.first.functions.first
      source = Expressir::Eval::Values::Aggregate.of(:set, [1, 2, 3])
      result = described_class.evaluate(
        function.statements.first.expression, env.push({ "s" => source })
      )
      expect(result).to eq(Expressir::Eval::Values::Aggregate.of(:set, [2, 3]))
    end

    it "intersects SETs per table 16" do
      repository = Expressir::Express::Parser.from_exp(<<~EXPRESS)
        SCHEMA eval_probe;
          FUNCTION f(a : SET OF INTEGER; b : SET OF INTEGER) : SET OF INTEGER;
            RETURN (a * b);
          END_FUNCTION;
        END_SCHEMA;
      EXPRESS
      function = repository.schemas.first.functions.first
      one = Expressir::Eval::Values::Aggregate.of(:set, [1, 2, 3])
      two = Expressir::Eval::Values::Aggregate.of(:set, [2, 3, 4])
      result = described_class.evaluate(
        function.statements.first.expression,
        env.push({ "a" => one, "b" => two }),
      )
      expect(result).to eq(Expressir::Eval::Values::Aggregate.of(:set, [2, 3]))
    end

    it "rejects LIST difference and intersection (tables 16 and 18 cover bag/set)" do
      expect { evaluate("[1, 2, 3] - 2") }
        .to raise_error(Expressir::Eval::Error, /difference requires/)
      expect { evaluate("[1, 2, 3] * [2, 3, 4]") }
        .to raise_error(Expressir::Eval::Error, /intersection requires/)
    end

    it "filters through QUERY" do
      repository = Expressir::Express::Parser.from_exp(<<~EXPRESS)
        SCHEMA eval_probe;
          FUNCTION f(xs : LIST OF INTEGER) : LIST OF INTEGER;
            RETURN (QUERY(x <* xs | x > 2));
          END_FUNCTION;
        END_SCHEMA;
      EXPRESS
      function = repository.schemas.first.functions.first
      source = Expressir::Eval::Values::Aggregate.of(:list, [1, 2, 3, 4])
      inner = env.push({ "xs" => source })
      result = described_class.evaluate(function.statements.first.expression, inner)
      expect(result).to eq(Expressir::Eval::Values::Aggregate.of(:list, [3, 4]))
    end
  end

  describe "errors" do
    it "raises on unbound identifiers" do
      expect { evaluate("nope + 1") }.to raise_error(Expressir::Eval::Error, /unbound/)
    end

    it "raises on domain violations" do
      expect { evaluate("'a' + 1") }
        .to raise_error(Expressir::Eval::Error, /addition requires/)
    end
  end
end
