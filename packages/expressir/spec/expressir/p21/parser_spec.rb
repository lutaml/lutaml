# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.eengine/06 step 1: the exchange-structure reader.
RSpec.describe Expressir::P21::Parser do
  let(:population) do
    described_class.parse(File.read(Expressir.root_path.join("spec/fixtures/p21/exchange_structure.p21")))
  end

  it "parses the header entities" do
    expect(population.header.keys).to eq(%w[FILE_DESCRIPTION FILE_NAME FILE_SCHEMA])
  end

  it "keeps header string lists as lists" do
    expect(population.header["FILE_DESCRIPTION"].first).to eq(["A demonstration", "second line"])
  end

  it "unescapes doubled quotes in strings" do
    name = population.header["FILE_NAME"].first
    expect(population.header["FILE_NAME"].size).to eq(7)
    expect(name).to eq("demo.stp")
  end

  it "records the FILE_SCHEMA name" do
    expect(population.header["FILE_SCHEMA"].first).to eq(["the_schema"])
  end

  it "parses simple instances with all value kinds" do
    record = population.instances["#1"]
    expect(record.keyword).to eq("DEEP")
    expect(record.params).to eq([
                                  "a string with 'quotes'",
                                  Expressir::P21::Enumeration.new("GOOD"),
                                  Expressir::P21::Binary.new("0A1F"),
                                  :derived,
                                  :unset,
                                ])
  end

  it "parses nested lists, references and typed parameters" do
    record = population.instances["#2"]
    expect(record.params.first).to eq([1, 2, 3])
    expect(record.params[1]).to eq("#1")
    expect(record.params.last).to eq(Expressir::P21::TypedValue.new("MAGNITUDE", [5]))
    expect(population.instances["#3"].params).to eq([Expressir::P21::Enumeration.new("BAD")])
  end

  it "parses complex instances into records" do
    complex = population.instances["#4"]
    expect(complex).to be_a(Expressir::P21::ComplexRecord)
    expect(complex.records.map(&:keyword)).to eq(%w[SUB_ONE SUB_TWO])
    expect(complex.records.first.params).to eq([1])
  end

  it "parses references to complex instances" do
    expect(population.instances["#5"].params).to eq(["#1", "#4"])
  end

  it "indexes every instance by its #id" do
    expect(population.instances.keys).to eq(%w[#1 #2 #3 #4 #5])
  end
end
