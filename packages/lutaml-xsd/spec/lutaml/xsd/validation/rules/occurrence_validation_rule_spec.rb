# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/rules/occurrence_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"

RSpec.describe Lutaml::Xsd::Validation::Rules::OccurrenceValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  # Helper to create a moxml element with children
  def create_moxml_element(name, children = [])
    fixture = Struct.new(:name, :children, :namespace, :attributes)
    fixture.new(name, children, nil, [])
  end

  # Helper to create a moxml child element
  def create_moxml_child(name, namespace = nil)
    child = Struct.new(:name, :namespace).new(name, namespace)
    child.define_singleton_method(:element?) { true }
    child
  end

  describe "#category" do
    it "returns :constraint" do
      expect(rule.category).to eq(:constraint)
    end
  end

  describe "#description" do
    it "returns a description" do
      expect(rule.description).to be_a(String)
      expect(rule.description).not_to be_empty
    end
  end

  describe "#validate" do
    let(:navigator) do
      Object.new.tap do |nav|
        nav.define_singleton_method(:current_xpath) { "/root" }
      end
    end

    context "when schema particle is nil" do
      let(:moxml_element) { create_moxml_element("parent", []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with element occurrence constraints" do
      context "when minOccurs is satisfied" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="child" type="xs:string" minOccurs="1" maxOccurs="unbounded"/>
            </xs:schema>
          XSD
        end

        let(:child1) { create_moxml_child("child") }
        let(:child2) { create_moxml_child("child") }
        let(:moxml_element) { create_moxml_element("parent", [child1, child2]) }
        let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:schema_element) { schema.element.first }

        it "does not report min occurs error" do
          rule.validate(xml_element, schema_element, collector)

          min_errors = collector.errors.select do |e|
            e.code == "min_occurs_violation"
          end
          expect(min_errors).to be_empty
        end
      end

      context "when minOccurs is violated" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="child" type="xs:string" minOccurs="2" maxOccurs="unbounded"/>
            </xs:schema>
          XSD
        end

        let(:moxml_element) { create_moxml_element("parent", []) }
        let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:schema_element) { schema.element.first }

        it "reports min occurs violation" do
          rule.validate(xml_element_empty, schema_element, collector)

          expect(collector.errors.size).to be > 0
          error = collector.errors.find { |e| e.code == "min_occurs_violation" }
          expect(error).not_to be_nil
          expect(error.message).to include("must occur at least 2 time(s)")
        end

        it "includes suggestion" do
          rule.validate(xml_element_empty, schema_element, collector)

          error = collector.errors.find { |e| e.code == "min_occurs_violation" }
          expect(error.suggestion).not_to be_nil
        end
      end

      context "when maxOccurs is violated" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="child" type="xs:string" minOccurs="1" maxOccurs="1"/>
            </xs:schema>
          XSD
        end

        let(:child1) { create_moxml_child("child") }
        let(:child2) { create_moxml_child("child") }
        let(:moxml_element) { create_moxml_element("parent", [child1, child2]) }
        let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:schema_element) { schema.element.first }

        it "reports max occurs violation" do
          rule.validate(xml_element, schema_element, collector)

          expect(collector.errors.size).to be > 0
          error = collector.errors.find { |e| e.code == "max_occurs_violation" }
          expect(error).not_to be_nil
          expect(error.message).to include("must occur at most 1 time(s)")
        end

        it "includes suggestion to remove occurrences" do
          rule.validate(xml_element, schema_element, collector)

          error = collector.errors.find { |e| e.code == "max_occurs_violation" }
          expect(error.suggestion).to include("Remove")
        end
      end

      context "when maxOccurs is unbounded" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="child" type="xs:string" minOccurs="1" maxOccurs="unbounded"/>
            </xs:schema>
          XSD
        end

        let(:many_children) do
          Array.new(100) { create_moxml_child("child") }
        end
        let(:moxml_element_many) do
          create_moxml_element("parent", many_children)
        end
        let(:xml_element_many) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element_many, navigator) }

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:schema_element) { schema.element.first }

        it "does not report max occurs error" do
          rule.validate(xml_element_many, schema_element, collector)

          max_errors = collector.errors.select do |e|
            e.code == "max_occurs_violation"
          end
          expect(max_errors).to be_empty
        end
      end

      context "when a choice's only alternative is a wildcard" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                       targetNamespace="urn:t" elementFormDefault="qualified"
                       xmlns:t="urn:t">
              <xs:element name="doc">
                <xs:complexType>
                  <xs:choice>
                    <xs:any processContents="lax"/>
                  </xs:choice>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          XSD
        end

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:choice) do
          schema.element.first.complex_type.choice
        end

        it "counts a child admitted by the wildcard as present" do
          child = create_moxml_child("note")
          parent = Lutaml::Xsd::Validation::XmlElement.new(
            create_moxml_element("doc", [child]), navigator
          )

          rule.validate(parent, choice, collector)

          min_errors = collector.errors.select do |e|
            e.code == "choice_min_occurs_violation"
          end
          expect(min_errors).to be_empty
        end

        it "reports the min violation when no child is present" do
          parent = Lutaml::Xsd::Validation::XmlElement.new(
            create_moxml_element("doc", []), navigator
          )

          rule.validate(parent, choice, collector)

          min_errors = collector.errors.select do |e|
            e.code == "choice_min_occurs_violation"
          end
          expect(min_errors).not_to be_empty
        end
      end

      context "when a repeating wildcard alternative absorbs children" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                       targetNamespace="urn:t" elementFormDefault="qualified">
              <xs:element name="doc">
                <xs:complexType>
                  <xs:choice>
                    <xs:any namespace="##other" minOccurs="4" maxOccurs="6"/>
                  </xs:choice>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          XSD
        end

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:choice) do
          schema.element.first.complex_type.choice
        end

        it "counts one choice occurrence for one wildcard occurrence" do
          children = Array.new(4) { create_moxml_child("other") }
          parent = Lutaml::Xsd::Validation::XmlElement.new(
            create_moxml_element("doc", children), navigator
          )

          rule.validate(parent, choice, collector)

          max_errors = collector.errors.select do |e|
            e.code == "choice_max_occurs_violation"
          end
          expect(max_errors).to be_empty
        end
      end

      context "when a sequence contains an xs:ref particle" do
        let(:xsd_xml) do
          <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                       targetNamespace="urn:t" elementFormDefault="qualified"
                       xmlns:t="urn:t">
              <xs:element name="item"/>
              <xs:element name="doc">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element ref="t:item" minOccurs="1" maxOccurs="1"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:schema>
          XSD
        end

        let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
        let(:sequence) do
          schema.element.last.complex_type.sequence
        end
        let(:repository) do
          repo_class = Class.new do
            def initialize(schemas)
              @schemas = schemas
            end

            def all_schemas
              @schemas
            end
          end
          Lutaml::Xsd::Validation::SchemaDefinitionResolver.new(
            repo_class.new({ "urn:t" => schema }),
          )
        end

        it "counts the referenced declaration's instance element" do
          child = create_moxml_child("item", Struct.new(:uri).new("urn:t"))
          parent = Lutaml::Xsd::Validation::XmlElement.new(
            create_moxml_element("doc", [child]), navigator
          )

          rule.validate(parent, sequence, collector, repository: repository)

          min_errors = collector.errors.select do |e|
            e.code == "min_occurs_violation"
          end
          expect(min_errors).to be_empty
        end
      end
    end
  end
end
