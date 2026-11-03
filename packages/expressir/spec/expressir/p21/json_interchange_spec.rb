# frozen_string_literal: true

require "spec_helper"
require "expressir"

RSpec.describe Expressir::P21::Json do
  let(:population) do
    Expressir::P21::Parser.parse(
      File.read(Expressir.root_path.join("spec/fixtures/p21/exchange_structure.p21")),
    )
  end

  it "round-trips a population through JSON value-identically" do
    value = described_class.to_value(population)
    expect(described_class.population(value).instances)
      .to eq(population.instances)
  end

  it "tags the Part 21 value kinds explicitly" do
    value = described_class.to_value(population)
    deep = value["instances"]["#1"]["params"]
    expect(deep).to include({ "enum" => "GOOD" }, { "binary" => "0A1F" },
                            { "derived" => true }, { "unset" => true })
    expect(value["instances"]["#2"]["params"][1]).to eq({ "ref" => "#1" })
  end
end
