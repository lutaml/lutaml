# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.eengine/06 step 2: population validation against a loaded schema.
RSpec.describe Expressir::P21::Validator do
  subject(:notes) { described_class.validate(population, schema) }

  let(:schema) do
    Expressir::Express::Parser.from_exp(
      File.read(Expressir.root_path.join("spec/fixtures/p21/schema.exp")),
    ).schemas.first
  end

  let(:population) do
    Expressir::P21::Parser.parse(
      File.read(Expressir.root_path.join("spec/fixtures/p21/exchange_structure.p21")),
    )
  end

  it "finds no issues in the consistent fixture" do
    expect(notes).to be_empty
  end

  it "is valid" do
    expect(described_class.valid?(notes)).to be(true)
  end

  it "flags an instance keyword that is not declared" do
    population.instances["#9"] = Expressir::P21::Record.new("UNDECLARED", [])
    ids = described_class.validate(population, schema)
      .select { |note| note.id == :p21_unknown_entity }
    expect(ids.map(&:instance)).to eq(["#9"])
    expect(described_class.valid?(ids)).to be(false)
  end

  it "flags an arity mismatch" do
    population.instances["#1"].params.pop
    notes = described_class.validate(population, schema)
    expect(notes.map(&:id)).to include(:p21_arity_mismatch)
  end

  it "flags a reference to a missing instance" do
    population.instances.delete("#1")
    notes = described_class.validate(population, schema)
    expect(notes.map(&:id)).to include(:p21_unknown_reference)
  end

  it "flags an enumeration value outside the type" do
    population.instances["#3"].params[0] = Expressir::P21::Enumeration.new("UGLY")
    notes = described_class.validate(population, schema)
    expect(notes.map(&:id)).to include(:p21_enum_value)
  end

  it "flags a typed parameter keyword that does not resolve" do
    population.instances["#2"].params[-1] =
      Expressir::P21::TypedValue.new("NOSUCH", [5])
    notes = described_class.validate(population, schema)
    expect(notes.map(&:id)).to include(:p21_unknown_typed_keyword)
  end

  it "flags complex records with no common supertype" do
    population.instances["#4"] = Expressir::P21::ComplexRecord.new([
                                                                     Expressir::P21::Record.new("SUB_ONE", [1]),
                                                                     Expressir::P21::Record.new("THINGS", [Expressir::P21::Enumeration.new("BAD")]),
                                                                   ])
    notes = described_class.validate(population, schema)
    expect(notes.map(&:id)).to include(:p21_complex_clique)
  end

  it "flags a FILE_SCHEMA mismatch as a warning" do
    mismatched = Expressir::P21::Parser.parse(
      File.read(Expressir.root_path.join("spec/fixtures/p21/exchange_structure.p21"))
          .sub("the_schema", "other_schema"),
    )
    notes = described_class.validate(mismatched, schema)
    expect(notes.map(&:id)).to eq([:p21_schema_mismatch])
    expect(described_class.valid?(notes)).to be(true)
  end
end
