# frozen_string_literal: true

require "spec_helper"
require "moxml"
require "lutaml/xsd/validation/rules/type_validation_rule"
require "lutaml/xsd/validation/result_collector"
require "lutaml/xsd/validation/validation_configuration"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/engine_context"

ENGINE_SUPPORTED = Lutaml::Xsd::Validation::EngineContext.xsd_supported?(
  Moxml::Context.new,
)

RSpec.describe Lutaml::Xsd::Validation::Rules::TypeValidationRule do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  let(:xsd_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="date" type="xs:date"/>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:schema_element) { schema.element.first }

  let(:navigator) do
    Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/date" }
    end
  end
  let(:xml_element) do
    Lutaml::Xsd::Validation::XmlElement.new(moxml_element, navigator)
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
  let(:engine) do
    Lutaml::Xsd::Validation::EngineContext.compile(
      engine_repository, context: Moxml::Context.new
    )
  end
  let(:engine_rule) { described_class.new(engine_context: engine) }

  describe "#validate with engine context", if: ENGINE_SUPPORTED do
    context "with a builtin-typed element" do
      let(:moxml_element) do
        Moxml::Context.new.parse("<date>2024-01-15</date>").root
      end

      it "accepts valid lexical values" do
        engine_rule.validate(xml_element, schema_element, collector)

        expect(collector.errors).to be_empty
      end
    end

    context "with an invalid builtin lexical value" do
      let(:moxml_element) do
        Moxml::Context.new.parse("<date>not-a-date</date>").root
      end

      it "reports a type error" do
        engine_rule.validate(xml_element, schema_element, collector)

        codes = collector.errors.map(&:code)
        expect(codes).to include("type_validation_error")
      end
    end

    context "when the engine cannot answer" do
      let(:moxml_element) do
        Moxml::Context.new.parse("<date>2024-01-15</date>").root
      end
      let(:empty_engine) do
        described_class.new(engine_context: nil)
      end

      it "falls back to existing (no-op) behavior" do
        empty_engine.validate(xml_element, schema_element, collector)

        expect(collector.errors).to be_empty
      end
    end
  end

  describe "#validate without engine context" do
    let(:moxml_element) do
      Moxml::Context.new.parse("<date>not-a-date</date>").root
    end

    it "checks builtin lexicals the value space can decide" do
      rule.validate(xml_element, schema_element, collector)

      codes = collector.errors.map(&:code)
      expect(codes).to include("type_validation_error")
    end
  end
end

# Whether lutaml-model maps the nested xs:simpleType inside xs:list;
# unmapped models keep inline item types unchecked.
LIST_SIMPLETYPE_MAPPED = begin
  probe = Lutaml::Xml::Schema::Xsd.parse(
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
    "<xs:element name=\"r\"><xs:simpleType><xs:list><xs:simpleType>" \
    '<xs:restriction base="xs:string"/>' \
    "</xs:simpleType></xs:list></xs:simpleType></xs:element></xs:schema>",
  )
  Lutaml::Xml::Schema::Xsd::SimpleType === probe.element.first
    .simple_type.list.simple_type
rescue StandardError
  false
end

RSpec.describe Lutaml::Xsd::Validation::Rules::TypeValidationRule,
               "range, list and union facets" do
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:collector) { Lutaml::Xsd::Validation::ResultCollector.new(config) }
  let(:rule) { described_class.new }

  def validate_value(schema_xml, value, validating_rule: rule)
    schema = Lutaml::Xml::Schema::Xsd.parse(schema_xml)
    root = Moxml::Context.new.parse("<r>#{value}</r>").root
    navigator = Object.new.tap do |nav|
      nav.define_singleton_method(:current_xpath) { "/r" }
    end
    xml_element = Lutaml::Xsd::Validation::XmlElement.new(root, navigator)
    validating_rule.validate(xml_element, schema.element.first, collector)
    collector
  end

  context "with numeric range facets" do
    let(:schema_xml) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="r">
            <xs:simpleType>
              <xs:restriction base="xs:integer">
                <xs:minInclusive value="1"/>
                <xs:maxExclusive value="10"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "accepts a value inside the range" do
      collector = validate_value(schema_xml, "5")

      expect(collector.errors).to be_empty
    end

    it "reports a value below minInclusive" do
      collector = validate_value(schema_xml, "0")

      expect(collector.errors.map(&:code))
        .to include("min_inclusive_violation")
    end

    it "reports a value equal to maxExclusive" do
      collector = validate_value(schema_xml, "10")

      expect(collector.errors.map(&:code))
        .to include("max_exclusive_violation")
    end
  end

  context "with a list type" do
    let(:schema_xml) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="r">
            <xs:simpleType>
              <xs:list>
                <xs:simpleType>
                  <xs:restriction base="xs:string">
                    <xs:enumeration value="a"/>
                    <xs:enumeration value="b"/>
                  </xs:restriction>
                </xs:simpleType>
              </xs:list>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "accepts a space-separated list of valid items",
       if: LIST_SIMPLETYPE_MAPPED do
      collector = validate_value(schema_xml, "a b")

      expect(collector.errors).to be_empty
    end

    it "reports an invalid list item",
       if: LIST_SIMPLETYPE_MAPPED do
      collector = validate_value(schema_xml, "a z")

      expect(collector.errors.map(&:code)).to include("enumeration_violation")
    end
  end

  context "with a union type" do
    let(:schema_xml) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="r">
            <xs:simpleType>
              <xs:union>
                <xs:simpleType>
                  <xs:restriction base="xs:string">
                    <xs:enumeration value="x"/>
                  </xs:restriction>
                </xs:simpleType>
                <xs:simpleType>
                  <xs:restriction base="xs:string">
                    <xs:enumeration value="y"/>
                  </xs:restriction>
                </xs:simpleType>
              </xs:union>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "accepts a value matching any member" do
      collector = validate_value(schema_xml, "y")

      expect(collector.errors).to be_empty
    end

    it "reports a value matching no member" do
      collector = validate_value(schema_xml, "z")

      expect(collector.errors.map(&:code)).to include("union_violation")
    end
  end

  context "with a union of builtin memberTypes", if: ENGINE_SUPPORTED do
    let(:schema_xml) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="value">
            <xs:simpleType>
              <xs:union memberTypes="xs:int xs:date"/>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD
    end

    let(:engine) do
      repo = Class.new do
        def initialize(schemas)
          @schemas = schemas
        end

        def all_schemas
          @schemas
        end
      end.new({ nil => Lutaml::Xml::Schema::Xsd.parse(schema_xml) })
      Lutaml::Xsd::Validation::EngineContext.compile(
        repo, context: Moxml::Context.new
      )
    end

    it "accepts a value matching a builtin member via a wired context" do
      rule = described_class.new
      rule.engine_context = engine
      collector = validate_value(schema_xml, "42", validating_rule: rule)

      expect(collector.errors).to be_empty
    end

    it "reports a value matching no builtin member" do
      rule = described_class.new
      rule.engine_context = engine
      collector = validate_value(schema_xml, "not-an-int-or-date",
                                 validating_rule: rule)

      expect(collector.errors.map(&:code)).to include("union_violation")
    end
  end
end
