# frozen_string_literal: true

require "spec_helper"

# TODO.compat/06: SchemaCompare deltas classified breaking vs additive
# through the subtype graph, with the ISO 10303-11 Annex K deprecation
# policy. Acceptance: a supertype attribute removal classifies
# breaking (with its affected subtypes); a new subtype classifies
# additive.
RSpec.describe Expressir::Express::ChangeClassification do
  def parse(text)
    Expressir::Express::Parser.from_exp(text).schemas.first
  end

  let(:base) do
    parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
          id : STRING;
        END_ENTITY;
        ENTITY circle SUBTYPE OF (shape);
          radius : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  def deltas_between(base, revised)
    Expressir::Express::SchemaCompare.compare(base, revised)
  end

  def classify(base, revised, **options)
    described_class.apply(deltas_between(base, revised), base, **options)
  end

  it "classifies a supertype attribute removal as breaking with affected subtypes" do
    revised = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
        END_ENTITY;
        ENTITY circle SUBTYPE OF (shape);
          radius : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    classified = classify(base, revised)
    removal = classified.find do |delta|
      delta.path == "demo.shape.id"
    end

    expect(removal.op).to eq(:removed)
    expect(removal.classification.value)
      .to eq(described_class::BREAKING)
    expect(removal.classification.affected_subtypes).to eq(["circle"])
    expect(removal.classification.deprecated).to be(false)
  end

  it "classifies a new subtype as additive" do
    revised = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
          id : STRING;
        END_ENTITY;
        ENTITY circle SUBTYPE OF (shape);
          radius : REAL;
        END_ENTITY;
        ENTITY square SUBTYPE OF (shape);
          side : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    classified = classify(base, revised)
    added = classified.find { |delta| delta.path == "demo.square" }

    expect(added.op).to eq(:added)
    expect(added.classification.value)
      .to eq(described_class::ADDITIVE)
    expect(added.classification.affected_subtypes).to be_empty
  end

  it "classifies a whole-declaration removal as breaking" do
    revised = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
          id : STRING;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    classified = classify(base, revised)
    removal = classified.find { |delta| delta.path == "demo.circle" }

    expect(removal.classification.value)
      .to eq(described_class::BREAKING)
  end

  it "classifies a signature change as breaking" do
    revised = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
          id : INTEGER;
        END_ENTITY;
        ENTITY circle SUBTYPE OF (shape);
          radius : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    classified = classify(base, revised)
    changed = classified.find { |delta| delta.path == "demo.shape.id" }

    expect(changed.op).to eq(:changed)
    expect(changed.classification.value)
      .to eq(described_class::BREAKING)
  end

  it "flags an announced removal per the deprecation policy" do
    revised = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
        END_ENTITY;
        ENTITY circle SUBTYPE OF (shape);
          radius : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    classified = classify(base, revised, deprecated: ["demo.shape.id"])
    removal = classified.find { |delta| delta.path == "demo.shape.id" }

    expect(removal.classification.deprecated).to be(true)
    expect(removal.classification.value)
      .to eq(described_class::BREAKING)
  end

  it "leaves deltas unclassified until the engine runs" do
    revised = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY shape;
          id : STRING;
        END_ENTITY;
        ENTITY circle SUBTYPE OF (shape);
          radius : REAL;
        END_ENTITY;
        ENTITY square SUBTYPE OF (shape);
          side : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    raw = deltas_between(base, revised).find { |delta| delta.path == "demo.square" }
    expect(raw.classification).to be_nil

    described_class.apply([raw], base)
    expect(raw.classification.value).to eq(described_class::ADDITIVE)
  end
end
