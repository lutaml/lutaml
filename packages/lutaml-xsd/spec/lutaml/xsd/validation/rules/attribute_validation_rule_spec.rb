# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/rules/attribute_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_attribute"
require "lutaml/xsd/validation/xml_navigator"
require "ostruct"

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

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
    let(:xsd_xml) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="person">
            <xs:complexType>
              <xs:attribute name="id" use="required"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end
    let(:schema_def) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml).element.first }

    def xml_element_for(xml)
      root = Moxml::Context.new.parse(xml).root
      navigator = Object.new.tap do |nav|
        nav.define_singleton_method(:current_xpath) { "/root/element" }
      end
      Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    end

    context "when schema element is nil" do
      it "does not validate" do
        rule.validate(xml_element_for('<person id="123"/>'), nil, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with required attributes" do
      it "does not report error when required attribute is present" do
        rule.validate(xml_element_for('<person id="123"/>'), schema_def,
                      collector)

        required_errors = collector.errors.select do |e|
          e.code == "required_attribute_missing"
        end
        expect(required_errors).to be_empty
      end

      it "reports required attribute missing error" do
        rule.validate(xml_element_for("<person/>"), schema_def, collector)

        expect(collector.errors.size).to be > 0
        error = collector.errors.find do |e|
          e.code == "required_attribute_missing"
        end
        expect(error).not_to be_nil
        expect(error.message).to include("Required attribute 'id' is missing")
      end

      it "includes suggestion" do
        rule.validate(xml_element_for("<person/>"), schema_def, collector)

        error = collector.errors.find do |e|
          e.code == "required_attribute_missing"
        end
        expect(error.suggestion).not_to be_nil
        expect(error.suggestion).to include("id")
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule,
               "xs:anyAttribute wildcard handling" do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }
  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/w"
                 elementFormDefault="qualified">
        <xs:element name="settings">
          <xs:complexType>
            <xs:complexContent>
              <xs:restriction base="xs:anyType">
                <xs:attribute name="lang"/>
                <xs:anyAttribute namespace="##targetNamespace ##local"
                                 processContents="strict"/>
              </xs:restriction>
            </xs:complexContent>
          </xs:complexType>
        </xs:element>
        <xs:attribute name="known" type="xs:string"/>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ "http://example.com/w" => schema })
  end
  let(:resolver) do
    Lutaml::Xsd::Validation::SchemaDefinitionResolver.new(repository)
  end
  let(:schema_def) { resolver.resolve("settings", "http://example.com/w") }
  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/settings" }
    end
  end

  def validate_xml(xml)
    root = Moxml::Context.new.parse(xml).root
    xml_element = Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    rule.validate(xml_element, schema_def, collector, repository: resolver)
    collector
  end

  it "accepts a wildcard-permitted declared attribute" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" ' \
      'xmlns:w="http://example.com/w" lang="en" w:known="x"/>',
    )

    expect(collector.errors).to be_empty
  end

  it "reports an undeclared attribute under strict processing" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" lang="en" bogus="1"/>',
    )

    codes = collector.errors.map(&:code)
    expect(codes).to include("wildcard_undeclared_attribute")
    expect(codes).not_to include("unexpected_attribute")
  end

  it "reports unexpected for a namespace outside the wildcard list" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" ' \
      'xmlns:o="http://other.example" o:x="1"/>',
    )

    expect(collector.errors.map(&:code)).to include("unexpected_attribute")
  end

  it "keeps the wildcard from bypassing namespace violations" do
    collector = validate_xml(
      '<settings xmlns="http://example.com/w" ' \
      'xmlns:o="http://other.example" lang="en" o:y="2"/>',
    )

    expect(collector.errors.map(&:code)).to include("unexpected_attribute")
  end
end

# Whether lutaml-model maps the complexType-level anyAttribute; older
# parses expose no accessor and types carrying the wildcard keep the
# pre-wildcard behavior.
COMPLEX_WILDCARD_MAPPED = begin
  probe = Lutaml::Xml::Schema::Xsd.parse(
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
    '<xs:complexType name="t"><xs:anyAttribute namespace="##local"/>' \
    "</xs:complexType></xs:schema>",
  )
  !probe.complex_type.first.any_attribute.nil?
rescue StandardError
  false
end

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule,
               "complexType-level anyAttribute" do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }
  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/c"
                 elementFormDefault="qualified">
        <xs:element name="item">
          <xs:complexType>
            <xs:attribute name="id"/>
            <xs:anyAttribute namespace="##local"
                             processContents="strict"/>
          </xs:complexType>
        </xs:element>
        <xs:attribute name="known" type="xs:string"/>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ "http://example.com/c" => schema })
  end
  let(:resolver) do
    Lutaml::Xsd::Validation::SchemaDefinitionResolver.new(repository)
  end
  let(:schema_def) { resolver.resolve("item", "http://example.com/c") }
  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/item" }
    end
  end

  def validate_xml(xml)
    root = Moxml::Context.new.parse(xml).root
    xml_element = Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    rule.validate(xml_element, schema_def, collector, repository: resolver)
    collector
  end

  it "rejects an unprefixed attribute whose declaration lives in the target namespace under strict ##local processing",
     if: COMPLEX_WILDCARD_MAPPED do
    # The unprefixed attribute is in no namespace; a strict wildcard
    # demands a declaration in THAT namespace, and the only `known`
    # declaration is {http://example.com/c}known (wildO006 shape).
    collector = validate_xml(
      '<item xmlns="http://example.com/c" id="1" known="x"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("wildcard_undeclared_attribute")
  end

  it "rejects an undeclared attribute under strict processing",
     if: COMPLEX_WILDCARD_MAPPED do
    collector = validate_xml(
      '<item xmlns="http://example.com/c" id="1" bogus="1"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("wildcard_undeclared_attribute")
  end

  it "degrades to unexpected_attribute while the mapping is absent",
     unless: COMPLEX_WILDCARD_MAPPED do
    collector = validate_xml(
      '<item xmlns="http://example.com/c" id="1" known="x"/>',
    )

    expect(collector.errors.map(&:code)).to include("unexpected_attribute")
  end
end

RSpec.describe Lutaml::Xsd::Validation::Rules::AttributeValidationRule,
               "attribute type validation" do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }
  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/t"
                 elementFormDefault="qualified">
        <xs:element name="doc">
          <xs:complexType>
            <xs:attribute name="color">
              <xs:simpleType>
                <xs:restriction base="xs:string">
                  <xs:enumeration value="red"/>
                  <xs:enumeration value="green"/>
                </xs:restriction>
              </xs:simpleType>
            </xs:attribute>
            <xs:attribute name="code">
              <xs:simpleType>
                <xs:restriction base="xs:string">
                  <xs:pattern value="[A-Z]{3}"/>
                </xs:restriction>
              </xs:simpleType>
            </xs:attribute>
            <xs:attribute name="nick">
              <xs:simpleType>
                <xs:restriction base="xs:string">
                  <xs:maxLength value="4"/>
                </xs:restriction>
              </xs:simpleType>
            </xs:attribute>
            <xs:attribute name="level" type="levelType"/>
            <xs:attribute name="count" type="xs:int"/>
          </xs:complexType>
        </xs:element>
        <xs:simpleType name="levelType">
          <xs:restriction base="xs:int">
            <xs:minInclusive value="1"/>
            <xs:maxInclusive value="10"/>
          </xs:restriction>
        </xs:simpleType>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ "http://example.com/t" => schema })
  end
  let(:resolver) do
    Lutaml::Xsd::Validation::SchemaDefinitionResolver.new(repository)
  end
  let(:schema_def) { resolver.resolve("doc", "http://example.com/t") }
  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/doc" }
    end
  end

  def validate_xml(xml)
    root = Moxml::Context.new.parse(xml).root
    xml_element = Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    rule.validate(xml_element, schema_def, collector, repository: resolver)
    collector
  end

  it "accepts a value inside the enumeration" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" color="red"/>',
    )

    expect(collector.errors).to be_empty
  end

  it "reports an enumeration violation" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" color="blue"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("attribute_enumeration_violation")
  end

  it "reports a pattern violation" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" code="ab"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("attribute_pattern_violation")
  end

  it "accepts a value matching the pattern" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" code="ABC"/>',
    )

    expect(collector.errors).to be_empty
  end

  it "reports a length violation" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" nick="toolong"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("attribute_length_violation")
  end

  it "reports a range violation on a named simpleType" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" level="11"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("attribute_range_violation")
  end

  it "accepts a named-simpleType value inside the range" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" level="7"/>',
    )

    expect(collector.errors).to be_empty
  end

  it "checks builtin lexical values without an engine" do
    collector = validate_xml(
      '<doc xmlns="http://example.com/t" count="not-a-number"/>',
    )

    expect(collector.errors.map(&:code))
      .to include("attribute_lexical_violation")
  end
end
