# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.eengine/07: structural diff + machine-applicable patch.
RSpec.describe Expressir::Express::SchemaCompare do
  let(:base) do
    parse(<<~EXPRESS)
      SCHEMA demo;
        TYPE status = ENUMERATION OF (GOOD, BAD);
        END_TYPE;
        ENTITY thing;
          a : STRING;
          opt : OPTIONAL INTEGER;
        END_ENTITY;
        ENTITY other;
          z : status;
        END_ENTITY;
        FUNCTION f(x : INTEGER) : INTEGER;
          RETURN (x);
        END_FUNCTION;
      END_SCHEMA;
    EXPRESS
  end

  let(:revised) do
    parse(<<~EXPRESS)
      SCHEMA demo;
        TYPE status = ENUMERATION OF (GOOD, BAD, UGLY);
        END_TYPE;
        ENTITY thing;
          a : STRING;
          opt : INTEGER;
          added : REAL;
        END_ENTITY;
        ENTITY other;
          z : status;
        END_ENTITY;
        FUNCTION f(x : INTEGER) : INTEGER;
          RETURN (x);
        END_FUNCTION;
      END_SCHEMA;
    EXPRESS
  end

  def parse(exp)
    Expressir::Express::Parser.from_exp(exp).schemas.first
  end

  def delta_map(deltas)
    deltas.to_h { |delta| [delta.path, delta.op] }
  end

  it "reports added, removed and changed declarations" do
    extra = parse(<<~EXPRESS)
      SCHEMA demo;
        ENTITY extra; q : BOOLEAN; END_ENTITY;
      END_SCHEMA;
    EXPRESS
    revised.entities = [*revised.entities, *extra.entities]
    map = delta_map(described_class.compare(base, revised))
    expect(map["demo.extra"]).to eq(:added)
    expect(map["demo.status"]).to eq(:changed)
    expect(map).not_to have_key("demo.other")
    expect(map).not_to have_key("demo.f")
  end

  it "gives entity attributes their own sub-deltas" do
    map = delta_map(described_class.compare(base, revised))
    expect(map["demo.thing.opt"]).to eq(:changed)
    expect(map["demo.thing.added"]).to eq(:added)
  end

  it "reports removed declarations" do
    revised.entities.reject! { |entity| entity.id&.downcase == "other" }
    map = delta_map(described_class.compare(base, revised))
    expect(map["demo.other"]).to eq(:removed)
  end

  it "sees no deltas for identical schemas" do
    expect(described_class.compare(base, parse(Expressir::Express::Formatter.format(base)))).to be_empty
  end

  it "carries the revised node for added and changed deltas" do
    deltas = described_class.compare(base, revised)
    changed = deltas.find { |delta| delta.path == "demo.thing.opt" }
    expect(changed.node).to be_a(Expressir::Model::Declarations::Attribute)
    expect(changed.node.type).to be_a(Expressir::Model::DataTypes::Integer)
  end

  describe Expressir::Express::SchemaPatch do
    let(:base) do
      parse(<<~EXPRESS)
        SCHEMA demo;
          TYPE status = ENUMERATION OF (GOOD, BAD);
          END_TYPE;
          ENTITY thing;
            a : STRING;
            opt : OPTIONAL INTEGER;
          END_ENTITY;
          ENTITY other;
            z : status;
          END_ENTITY;
        END_SCHEMA;
      EXPRESS
    end

    let(:revised) do
      parse(<<~EXPRESS)
        SCHEMA demo;
          TYPE status = ENUMERATION OF (GOOD, BAD, UGLY);
          END_TYPE;
          ENTITY thing;
            a : STRING;
            opt : INTEGER;
            added : REAL;
          END_ENTITY;
          ENTITY fresh; q : BOOLEAN; END_ENTITY;
        END_SCHEMA;
      EXPRESS
    end

    def parse(exp)
      Expressir::Express::Parser.from_exp(exp).schemas.first
    end

    it "leaves the base schema untouched" do
      deltas = Expressir::Express::SchemaCompare.compare(base, revised)
      described_class.apply(base, deltas)
      expect(base.entities.map(&:id)).to eq(%w[thing other])
      expect(base.entities.first.attributes.map(&:id)).to eq(%w[a opt])
    end

    it "applies the deltas so the revised schema compares empty" do
      deltas = Expressir::Express::SchemaCompare.compare(base, revised)
      patched = described_class.apply(base, deltas)
      expect(Expressir::Express::SchemaCompare.compare(patched, revised)).to be_empty
    end

    it "keeps attribute position on change" do
      deltas = Expressir::Express::SchemaCompare.compare(base, revised)
      patched = described_class.apply(base, deltas)
      thing = patched.entities.find { |entity| entity.id == "thing" }
      expect(thing.attributes.map(&:id)).to eq(%w[a opt added])
    end

    it "applies an attribute removal" do
      deltas = [Expressir::Express::SchemaCompare::Delta.new(
        op: :removed, path: "demo.thing.a", node: nil,
      )]
      patched = described_class.apply(base, deltas)
      thing = patched.entities.find { |entity| entity.id == "thing" }
      expect(thing.attributes.map(&:id)).to eq(%w[opt])
    end
  end
end
