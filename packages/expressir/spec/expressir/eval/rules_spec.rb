# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "expressir/eval"

# TODO.sota/02 step 4: WHERE-rule checking over a Part 21 population
# (ISO 10303-11 9.4 — a rule is violated only when it evaluates false).
RSpec.describe Expressir::Eval::Rules do
  let(:schema) do
    Expressir::Express::Parser.from_exp(
      File.read(Expressir.root_path.join("spec/fixtures/eval/population.exp")),
    ).schemas.first
  end

  let(:population) do
    Expressir::P21::Parser.parse(
      File.read(Expressir.root_path.join("spec/fixtures/eval/population.p21")),
    )
  end

  it "passes every rule on a consistent population" do
    results = described_class.check(population, schema)
    expect(results.map(&:status).uniq).to eq([:pass])
    expect(described_class.violated?(results)).to be(false)
  end

  it "fails only the rule whose instance was corrupted" do
    population.instances["#1"].params[0] = ""
    results = described_class.check(population, schema)
    failures = described_class.failures(results)
    expect(failures.size).to eq(1)
    expect(failures.first.rule_id).to eq("named")
    expect(failures.first.instance).to eq("#1")
  end

  it "resolves cross-instance attribute chains in rules" do
    population.instances["#2"].params[0] = "a"
    results = described_class.check(population, schema)
    failures = described_class.failures(results)
    expect(failures.map(&:rule_id)).to eq(["different"])
  end
end
