# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.instance/01 part 1: instance typing (ISO 10303-11 9.2.5) —
# which entities a Part 21 instance conforms to, through the subtype
# graph, with ONEOF exclusivity (9.2.5.2) per complex record.
RSpec.describe Expressir::P21::Typing do
  let(:schema) do
    Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
      SCHEMA typing_demo;
      ENTITY base ABSTRACT SUPERTYPE OF (ONEOF(material, document));
      END_ENTITY;
      ENTITY material SUBTYPE OF (base); code : INTEGER; END_ENTITY;
      ENTITY document SUBTYPE OF (base); text : STRING; END_ENTITY;
      ENTITY other; note : STRING; END_ENTITY;
      ENTITY extender ABSTRACT SUPERTYPE OF (alpha ANDOR beta);
      END_ENTITY;
      ENTITY alpha SUBTYPE OF (extender); END_ENTITY;
      ENTITY beta SUBTYPE OF (extender); END_ENTITY;
      END_SCHEMA;
    EXP
  end

  let(:short_names) { { "MAT" => "material" } }

  def typing(short_names: nil)
    described_class.new(schema, short_names: short_names)
  end

  it "types a simple record with its supertype closure (9.2.5)" do
    record = Expressir::P21::Record.new("material", [1])
    expect(typing.of(record).filter_map(&:id).map(&:downcase))
      .to eq(%w[material base])
  end

  it "resolves short names (ISO 10303-21 12.3)" do
    record = Expressir::P21::Record.new("MAT", [1])
    expect(typing(short_names: short_names).of(record).filter_map(&:id)
      .map(&:downcase)).to include("material")
  end

  it "reports an unknown keyword (9.2.5)" do
    record = Expressir::P21::Record.new("ghost", [])
    expect(typing.issues(record).join).to include("ghost")
  end

  it "types a complex record as the union of its closures" do
    record = Expressir::P21::ComplexRecord.new([
                                                 Expressir::P21::Record.new("alpha", []),
                                                 Expressir::P21::Record.new("beta", []),
                                               ])
    expect(typing.of(record).filter_map(&:id).map(&:downcase))
      .to contain_exactly("alpha", "beta", "extender")
  end

  it "flags a repeated leaf in one complex instance (9.2.5)" do
    record = Expressir::P21::ComplexRecord.new([
                                                 Expressir::P21::Record.new("alpha", []),
                                                 Expressir::P21::Record.new("alpha", []),
                                               ])
    expect(typing.issues(record).join).to include("twice")
  end

  it "flags two leaves of one ONEOF group (9.2.5.2)" do
    record = Expressir::P21::ComplexRecord.new([
                                                 Expressir::P21::Record.new("material", [1]),
                                                 Expressir::P21::Record.new("document", ["t"]),
                                               ])
    expect(typing.issues(record).join)
      .to include("ONEOF group (9.2.5.2)")
  end

  it "accepts ANDOR siblings in one complex instance" do
    record = Expressir::P21::ComplexRecord.new([
                                                 Expressir::P21::Record.new("alpha", []),
                                                 Expressir::P21::Record.new("beta", []),
                                               ])
    expect(typing.issues(record)).to be_empty
  end
end
