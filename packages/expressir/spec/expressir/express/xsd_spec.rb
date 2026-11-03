# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Express::Xsd do
  def parse(schema_source)
    f = Tempfile.new(["xsd", ".exp"])
    f.write(schema_source)
    f.close
    repo = Expressir::Express::Parser.from_files([f.path])
    schema = repo.schemas.first
    [schema, f]
  end

  let(:schema_source) do
    <<~EXP
      SCHEMA demo;
      TYPE color = ENUMERATION OF (red, green); END_TYPE;
      TYPE label = STRING; END_TYPE;
      ENTITY base ABSTRACT SUPERTYPE; name : label; END_ENTITY;
      ENTITY widget SUBTYPE OF (base);
        count : INTEGER;
        tags : LIST [0:?] OF label;
        shade : color;
      END_ENTITY;
      END_SCHEMA;
    EXP
  end

  let(:xml) do
    schema, f = parse(schema_source)
    out = described_class.format(schema)
    f.unlink
    out
  end

  it "roots an xs:schema document with the xs namespace" do
    aggregate_failures do
      expect(xml).to include("<xs:schema")
      expect(xml).to include("xmlns:xs=\"http://www.w3.org/2001/XMLSchema\"")
    end
  end

  it "maps enumerations to simpleType facets" do
    aggregate_failures do
      expect(xml).to include("<xs:simpleType name=\"color\">")
      expect(xml).to include("<xs:enumeration value=\"red\">")
      expect(xml).to include("<xs:enumeration value=\"green\">")
    end
  end

  it "maps entities to element + complexType pairs" do
    aggregate_failures do
      expect(xml).to include("<xs:element name=\"widget\" type=\"widget\"")
      expect(xml).to include("<xs:complexType name=\"widget\">")
    end
  end

  it "links subtypes to their supertype via substitutionGroup" do
    expect(xml).to include("substitutionGroup=\"base\"")
  end

  it "maps built-ins and aggregates on attributes" do
    aggregate_failures do
      expect(xml).to include("<xs:element name=\"count\" type=\"xs:integer\"")
      expect(xml).to include("<xs:element name=\"tags\" type=\"label\" maxOccurs=\"unbounded\"")
    end
  end

  it "resolves attribute types to schema-local defined types" do
    expect(xml).to include("<xs:element name=\"name\" type=\"label\"")
  end

  it "derives subtypes from their supertype through xs:extension" do
    aggregate_failures do
      expect(xml).to include("<xs:complexContent>")
      expect(xml).to include("<xs:extension base=\"base\">")
    end
  end

  context "with a select type (v2, expressir #276)" do
    let(:schema_source) do
      <<~EXP
        SCHEMA demo;
        TYPE color = ENUMERATION OF (red, green); END_TYPE;
        TYPE label = STRING; END_TYPE;
        TYPE choice = SELECT (widget, gadget, color, label); END_TYPE;
        ENTITY widget; name : label; END_ENTITY;
        ENTITY gadget; shade : color; END_ENTITY;
        ENTITY holder; pick : choice; picks : LIST [0:?] OF choice; END_ENTITY;
        ENTITY mix SUBTYPE OF (widget, gadget); extra : label; END_ENTITY;
        END_SCHEMA;
      EXP
    end

    it "maps a select to a complexType with a choice over its members" do
      aggregate_failures do
        expect(xml).to include("<xs:complexType name=\"choice\">")
        expect(xml).to include("<xs:choice>")
      end
    end

    it "references entity members through their global elements" do
      aggregate_failures do
        expect(xml).to include("<xs:element ref=\"widget\"")
        expect(xml).to include("<xs:element ref=\"gadget\"")
      end
    end

    it "carries defined-type members by name and type" do
      aggregate_failures do
        expect(xml).to include("<xs:element name=\"color\" type=\"color\"")
        expect(xml).to include("<xs:element name=\"label\" type=\"label\"")
      end
    end

    it "types select-valued attributes with the select complexType" do
      aggregate_failures do
        expect(xml).to include("<xs:element name=\"pick\" type=\"choice\"")
        expect(xml).to include(
          "<xs:element name=\"picks\" type=\"choice\" maxOccurs=\"unbounded\"",
        )
      end
    end

    it "carries later parents' attributes for multiple inheritance" do
      mix = xml[/<xs:complexType name="mix">.*?<\/xs:complexType>/m]
      aggregate_failures do
        expect(mix).to include("<xs:extension base=\"widget\">")
        expect(mix).to include("<xs:element name=\"extra\" type=\"label\"")
        expect(mix).to include("<xs:element name=\"shade\" type=\"color\"")
      end
    end
  end
end
