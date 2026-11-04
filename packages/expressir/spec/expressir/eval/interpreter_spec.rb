# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "expressir/eval"

# TODO.sota/02 step 2: function and statement interpretation
# (ISO 10303-11 ch.13) with the pure builtins of ch.15.
RSpec.describe Expressir::Eval::Interpreter do
  let(:repository) { Expressir::Express::Parser.from_exp(schema_source) }
  let(:schema) { repository.schemas.first }
  let(:interpreter) { described_class.new(schema: schema) }
  let(:schema_source) do
    <<~EXPRESS
      SCHEMA eval_interp;
        FUNCTION gcd(a : INTEGER; b : INTEGER) : INTEGER;
          LOCAL
            x : INTEGER := a;
            y : INTEGER := b;
            t : INTEGER;
          END_LOCAL;
          REPEAT WHILE y > 0;
            t := y;
            y := x MOD y;
            x := t;
          END_REPEAT;
          RETURN (x);
        END_FUNCTION;

        FUNCTION fact(n : INTEGER) : INTEGER;
          IF n <= 1 THEN
            RETURN (1);
          END_IF;
          RETURN (n * fact(n - 1));
        END_FUNCTION;

        FUNCTION count_odds(n : INTEGER) : INTEGER;
          LOCAL
            total : INTEGER := 0;
          END_LOCAL;
          REPEAT i := 1 TO n;
            IF NOT ODD(i) THEN
              SKIP;
            END_IF;
            total := total + 1;
          END_REPEAT;
          RETURN (total);
        END_FUNCTION;

        FUNCTION first_above(ns : LIST OF INTEGER; threshold : INTEGER) : INTEGER;
          LOCAL
            found : INTEGER := -1;
          END_LOCAL;
          REPEAT j := 1 TO SIZEOF(ns);
            IF ns[j] > threshold THEN
              found := ns[j];
              ESCAPE;
            END_IF;
          END_REPEAT;
          RETURN (found);
        END_FUNCTION;

        FUNCTION classify(n : INTEGER) : STRING;
          LOCAL
            label_1 : STRING;
          END_LOCAL;
          CASE n OF
            0 : label_1 := 'zero';
            1, 2 : label_1 := 'small';
            OTHERWISE : label_1 := 'big';
          END_CASE;
          RETURN (label_1);
        END_FUNCTION;

        FUNCTION until_five(n : INTEGER) : INTEGER;
          LOCAL
            x : INTEGER := n;
          END_LOCAL;
          REPEAT UNTIL x >= 5;
            x := x + 1;
          END_REPEAT;
          RETURN (x);
        END_FUNCTION;
      END_SCHEMA;
    EXPRESS
  end

  def derive(function_name, arguments)
    Expressir::Eval::Environment.new(schema: schema)
    interpreter.call(function_name, arguments)
  end

  it "runs a WHILE loop with locals and MOD" do
    expect(derive("gcd", [48, 18])).to eq(6)
  end

  it "runs recursion" do
    expect(derive("fact", [5])).to eq(120)
  end

  it "skips iterations (SKIP) inside an increment REPEAT" do
    expect(derive("count_odds", [9])).to eq(5)
  end

  it "breaks out of a loop (ESCAPE) with its environment intact" do
    list = Expressir::Eval::Values::Aggregate.of(:list, [1, 4, 9, 16])
    expect(derive("first_above", [list, 5])).to eq(9)
  end

  it "selects CASE actions by label list and OTHERWISE" do
    expect(derive("classify", [2])).to eq("small")
    expect(derive("classify", [7])).to eq("big")
  end

  it "runs an UNTIL-controlled repeat" do
    expect(derive("until_five", [1])).to eq(5)
  end

  it "evaluates the math/string builtins" do
    environment = Expressir::Eval::Environment.new(schema: schema)
    expression = Expressir::Express::Parser.from_exp(<<~EXPRESS).schemas.first.constants.first.expression
      SCHEMA eval_builtin;
        CONSTANT
          c : REAL := ABS(-3) + SQRT(16) + LENGTH('abc');
        END_CONSTANT;
      END_SCHEMA;
    EXPRESS
    expect(Expressir::Eval::Expression.evaluate(expression, environment)).to eq(10.0)
  end

  it "reports a function that falls off the end without RETURN (13.7)" do
    broken = Expressir::Express::Parser.from_exp(<<~EXPRESS).schemas.first
      SCHEMA eval_broken;
        FUNCTION f(n : INTEGER) : INTEGER;
          LOCAL
            x : INTEGER := n;
          END_LOCAL;
          x := x + 1;
        END_FUNCTION;
      END_SCHEMA;
    EXPRESS
    expect { described_class.new(schema: broken).call("f", [1]) }
      .to raise_error(Expressir::Eval::Error, /without RETURN/)
  end
end
