# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/occurrence_product_guard"
require "lutaml/xsd/validation/engine_context"

RSpec.describe Lutaml::Xsd::Validation::OccurrenceProductGuard do
  def parse(xsd)
    Lutaml::Xml::Schema::Xsd.parse(xsd)
  end

  describe ".for_schema / #schema_safe?" do
    it "accepts a plain bounded model" do
      schema = parse <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="a" maxOccurs="3"/>
                <xs:element name="b" minOccurs="0"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      expect(described_class.for_schema(schema).schema_safe?(schema))
        .to be(true)
    end

    it "flags an unbounded element nested in a repeated sequence" do
      schema = parse <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="fooType">
            <xs:sequence>
              <xs:sequence maxOccurs="100">
                <xs:element name="a" maxOccurs="unbounded"/>
              </xs:sequence>
              <xs:element name="b"/>
              <xs:any namespace="##other" processContents="lax"/>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="doc" type="fooType"/>
        </xs:schema>
      XSD

      expect(described_class.for_schema(schema).schema_safe?(schema))
        .to be(false)
    end

    it "flags a named type only reachable from a top-level element" do
      schema = parse <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="boom">
            <xs:sequence maxOccurs="99999">
              <xs:sequence maxOccurs="99999">
                <xs:element name="a"/>
              </xs:sequence>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="doc" type="boom"/>
        </xs:schema>
      XSD

      expect(described_class.for_schema(schema).schema_safe?(schema))
        .to be(false)
    end
  end

  describe "#particles_safe?" do
    it "accepts small products" do
      schema = parse <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="a" minOccurs="0" maxOccurs="4"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
      particles = schema.element.first.complex_type.sequence
      guard = described_class.for_schema(schema)

      expect(guard.particles_safe?([particles])).to be(true)
    end
  end

  describe "engine integration" do
    it "excludes an occurrence-product schema from engine compilation" do
      schema = parse <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="fooType">
            <xs:sequence>
              <xs:sequence maxOccurs="100">
                <xs:element name="a" maxOccurs="unbounded"/>
              </xs:sequence>
              <xs:element name="b"/>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="doc" type="fooType"/>
        </xs:schema>
      XSD
      repository = Class.new do
        def initialize(schemas)
          @schemas = schemas
        end

        def all_schemas
          @schemas
        end
      end.new({ nil => schema })
      compiled = Lutaml::Xsd::Validation::EngineContext.compile(
        repository, context: Moxml::Context.new
      )

      # nil: no engine on this adapter. Otherwise the unsafe schema is
      # excluded, so the context has nothing compiled.
      expect(compiled.nil? || compiled.schemas.empty?).to be(true)
    end

    it "keeps an unassessable schema engine-inert without raising" do
      repository = Class.new do
        def all_schemas
          { "http://example.com/x" => "not-a-schema-object" }
        end
      end.new
      compiled = Lutaml::Xsd::Validation::EngineContext.compile(
        repository, context: Moxml::Context.new
      )

      # nil: no engine on this adapter. Otherwise the unassessable
      # schema keeps the engine inert.
      expect(compiled.nil? || compiled.schemas.empty?).to be(true)
    end
  end
end
