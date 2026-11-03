# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/rules/content_model_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"
require "moxml"

RSpec.describe Lutaml::Xsd::Validation::Rules::ContentModelValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  # Helper to create a moxml element with children
  def create_moxml_element(name, children = [])
    fixture = Struct.new(:name, :children, :namespace, :attributes)
    fixture.new(name, children, nil, [])
  end

  # Helper to create a moxml child element
  def create_moxml_child(name)
    child = Struct.new(:name, :namespace).new(name, nil)
    child.define_singleton_method(:element?) { true }
    child
  end

  describe "#category" do
    it "returns :structure" do
      expect(rule.category).to eq(:structure)
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

    context "when schema definition is nil" do
      let(:moxml_element) { create_moxml_element("parent", []) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      it "does not validate" do
        rule.validate(xml_element, nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with sequence content model" do
      let(:xsd_xml) do
        <<~XSD
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="parent">
              <xs:complexType>
                <xs:sequence>
                  <xs:element name="first" type="xs:string" minOccurs="1"/>
                  <xs:element name="second" type="xs:string" minOccurs="1"/>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XSD
      end

      let(:child1) { create_moxml_child("first") }
      let(:child2) { create_moxml_child("second") }
      let(:moxml_element) { create_moxml_element("parent", [child1, child2]) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
      let(:schema_def) { schema.element.first }

      it "validates sequence order" do
        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for correct sequence
        sequence_errors = collector.errors.select do |e|
          e.code.include?("sequence")
        end
        expect(sequence_errors).to be_empty
      end
    end

    context "with choice content model" do
      let(:xsd_xml) do
        <<~XSD
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="parent">
              <xs:complexType>
                <xs:choice>
                  <xs:element name="option1" type="xs:string"/>
                  <xs:element name="option2" type="xs:string"/>
                </xs:choice>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XSD
      end

      let(:child1) { create_moxml_child("option1") }
      let(:moxml_element) { create_moxml_element("parent", [child1]) }
      let(:xml_element) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
      let(:schema_def) { schema.element.first }

      it "validates choice alternatives" do
        rule.validate(xml_element, schema_def, collector)

        # Expect no errors for valid choice
        choice_errors = collector.errors.select do |e|
          e.code.include?("choice")
        end
        expect(choice_errors).to be_empty
      end
    end

    context "when choice is not satisfied" do
      let(:xsd_xml) do
        <<~XSD
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="parent">
              <xs:complexType>
                <xs:choice>
                  <xs:element name="option1" type="xs:string"/>
                </xs:choice>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XSD
      end

      let(:moxml_element) { create_moxml_element("parent", []) }
      let(:xml_element_empty) { Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator) }

      let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
      let(:schema_def) { schema.element.first }

      it "reports choice not satisfied error" do
        rule.validate(xml_element_empty, schema_def, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find { |e| e.code == "choice_not_satisfied" }
        expect(error).not_to be_nil
        expect(error.message).to include("must be present")
      end
    end
  end

  describe "#validate with engine context" do
    engine_supported = Lutaml::Xsd::Validation::EngineContext.xsd_supported?(
      Moxml::Context.new,
    )

    let(:xsd_xml) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="person">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="name" type="xs:string"/>
                <xs:element name="age" type="xs:integer"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end
    let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
    let(:schema_def) { schema.element.first }
    let(:engine_rule) { described_class.new(engine_context: engine) }
    let(:navigator) do
      Object.new.tap do |nav|
        nav.define_singleton_method(:current_xpath) { "/person" }
      end
    end

    # Some engine bindings cannot answer content checks at all (e.g.
    # moxml/leptris content_valid? raising on identity minting) — the
    # contract degrades to the Ruby walk and the engine cases are skipped.
    engine_content_capable = begin
      ctx = Moxml::Context.new
      compiled = ctx.xsd(xsd_xml)
      node = ctx.parse("<person><name>A</name></person>").root
      !compiled.content_valid?("person", node.children.to_a).nil?
    rescue StandardError
      false
    end
    let(:engine) do
      Lutaml::Xsd::Validation::EngineContext.compile(
        engine_repository, context: Moxml::Context.new
      )
    end
    let(:engine_repository) do
      Class.new do
        def initialize(schemas)
          @schemas = schemas
        end

        def all_schemas
          @schemas
        end
      end.new({ "http://example.com/test" => schema })
    end

    def real_xml_element(xml)
      moxml_root = Moxml::Context.new.parse(xml).root
      Lutaml::Xsd::Validation::XmlElement.new(moxml_root, navigator)
    end

    it "accepts a valid child order", if: engine_supported && engine_content_capable do
      element = real_xml_element(
        "<person><name>A</name><age>30</age></person>",
      )
      engine_rule.validate(element, schema_def, collector)

      expect(collector.errors).to be_empty
    end

    it "reports an invalid child order", if: engine_supported && engine_content_capable do
      element = real_xml_element(
        "<person><age>30</age><name>A</name></person>",
      )
      engine_rule.validate(element, schema_def, collector)

      expect(collector.errors.map(&:code)).to include("content_model_error")
    end

    it "reports content_model_error when the engine answers false" do
      engine = Object.new
      engine.define_singleton_method(:supported?) { true }
      engine.define_singleton_method(:content_valid) { |*, **| false }
      answering_rule = described_class.new(engine_context: engine)
      element = real_xml_element(
        "<person><age>30</age><name>A</name></person>",
      )
      answering_rule.validate(element, schema_def, collector)

      expect(collector.errors.map(&:code)).to include("content_model_error")
    end

    it "degrades to the Ruby walk when the engine cannot answer" do
      engine = Object.new
      engine.define_singleton_method(:supported?) { true }
      engine.define_singleton_method(:content_valid) { |*, **| nil }
      inert_engine_rule = described_class.new(engine_context: engine)
      element = real_xml_element(
        "<person><age>30</age><name>A</name></person>",
      )
      inert_engine_rule.validate(element, schema_def, collector)

      codes = collector.errors.map(&:code)
      expect(codes).not_to include("content_model_error")
      expect(codes).not_to be_empty
    end

    it "falls back to the Ruby walk when no engine context is given" do
      element = real_xml_element(
        "<person><age>30</age><name>A</name></person>",
      )
      plain_rule = described_class.new
      plain_rule.validate(element, schema_def, collector)

      expect(collector.errors).not_to be_empty
    end
  end
end
