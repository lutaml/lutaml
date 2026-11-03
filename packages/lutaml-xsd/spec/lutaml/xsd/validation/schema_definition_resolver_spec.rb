# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/schema_definition_resolver"

RSpec.describe Lutaml::Xsd::Validation::SchemaDefinitionResolver do
  let(:xsd_source) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:tns="http://example.com/test"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:element name="person" type="tns:t_person"/>
        <xs:complexType name="t_person">
          <xs:sequence>
            <xs:element name="name" type="xs:string"/>
            <xs:element name="age" type="xs:integer" minOccurs="0"/>
          </xs:sequence>
          <xs:attribute name="id" type="xs:string" use="required"/>
        </xs:complexType>
      </xs:schema>
    XSD
  end

  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }
  let(:repository) do
    Class.new do
      def initialize(schemas)
        @schemas = schemas
      end

      attr_reader :schemas

      def all_schemas
        @schemas
      end
    end.new({ "http://example.com/test" => schema })
  end

  subject(:resolver) { described_class.new(repository) }

  describe "#resolve" do
    it "resolves a top-level element in its target namespace" do
      element = resolver.resolve("person", "http://example.com/test")

      expect(element).not_to be_nil
      expect(element.name).to eq("person")
    end

    it "resolves an inline element in its target namespace" do
      element = resolver.resolve("name", "http://example.com/test")

      expect(element).not_to be_nil
      expect(element.type).to eq("xs:string")
    end

    it "does not resolve an element in a foreign namespace" do
      expect(resolver.resolve("person", "http://example.com/other")).to be_nil
    end

    it "falls back to a unique name match when the instance omits namespaces" do
      element = resolver.resolve("person", nil)

      expect(element).not_to be_nil
      expect(element.name).to eq("person")
    end

    it "keeps the fallback when a held schema is also nested as a resolved import" do
      importing = Lutaml::Xml::Schema::Xsd.parse(
        <<~XSD,
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://example.com/other">
            <xs:import namespace="http://example.com/test"
                       schemaLocation="test.xsd"/>
          </xs:schema>
        XSD
      )
      importing.import = [schema]
      nested_repository = Class.new do
        def initialize(schemas)
          @schemas = schemas
        end

        attr_reader :schemas

        def all_schemas
          @schemas
        end
      end.new(
        { "http://example.com/test" => schema,
          "http://example.com/other" => importing },
      )
      nested_resolver = described_class.new(nested_repository)

      element = nested_resolver.resolve("person", nil)

      expect(element).not_to be_nil
      expect(element.name).to eq("person")
    end

    it "returns nil for unknown names" do
      expect(resolver.resolve("no_such_element", nil)).to be_nil
    end
  end

  describe "#resolve_type" do
    it "resolves a named complex type reference" do
      element = resolver.resolve("person", "http://example.com/test")

      expect(resolver.resolve_type(element)).to be_a(Lutaml::Xsd::ComplexType)
      expect(resolver.resolve_type(element).name).to eq("t_person")
    end

    it "returns nil when the element has no type reference" do
      element = resolver.resolve("name", "http://example.com/test")

      expect(resolver.resolve_type(element)).to be_nil
    end
  end

  describe "#content_model_for" do
    it "returns the sequence particle of the referenced type" do
      element = resolver.resolve("person", "http://example.com/test")

      expect(resolver.content_model_for(element)).to be_a(Lutaml::Xsd::Sequence)
    end

    it "returns nil for simple-typed elements" do
      element = resolver.resolve("name", "http://example.com/test")

      expect(resolver.content_model_for(element)).to be_nil
    end
  end
end
