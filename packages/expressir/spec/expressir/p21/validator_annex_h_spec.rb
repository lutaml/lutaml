# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.eengine/06 step 3: the ISO 10303-21 Annex H worked example — a
# complete exchange structure (comments, short names, optional
# attributes) validated against its schema.
RSpec.describe Expressir::P21::Validator do
  let(:schema) do
    Expressir::Express::Parser.from_exp(
      File.read(Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp")),
    ).schemas.first
  end

  let(:population) do
    Expressir::P21::Parser.parse(
      File.read(Expressir.root_path.join("spec/fixtures/p21/annex_h.p21")),
    )
  end

  let(:short_names) do
    {
      "CPT" => "cartesian_point",
      "VX" => "vertex",
      "ED" => "edge",
      "ED_STRC" => "edge_logical_structure",
      "ED_LOOP" => "edge_loop",
    }
  end

  it "parses all 13 instances of the annex H model" do
    expect(population.instances.size).to eq(13)
    expect(population.instances.keys).to eq(
      %w[#1 #2 #3 #11 #12 #13 #16 #17 #18 #21 #22 #23 #24],
    )
  end

  it "reads the header FILE_SCHEMA" do
    expect(population.header["FILE_SCHEMA"]).to eq([["EXAMPLE_GEOMETRY"]])
  end

  it "validates the annex H population clean against its schema" do
    notes = described_class.validate(population, schema, short_names: short_names)
    expect(notes).to be_empty
  end

  it "flags short names that are not mapped" do
    notes = described_class.validate(population, schema)
    expect(notes.map(&:id)).to all(eq(:p21_unknown_entity))
  end

  it "flags an unknown short name" do
    notes = described_class.validate(population, schema,
                                     short_names: { "CPT" => "cartesian_point" })
    expect(notes.map(&:id)).to include(:p21_unknown_entity)
  end
end
