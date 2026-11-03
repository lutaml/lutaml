# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/validator"

# Whether lutaml-model maps the keyref `refer` attribute; when unmapped
# (UninitializedClass) dangling keyrefs cannot be detected and the rule
# degrades to valid.
REFER_MAPPED = begin
  minimal = Lutaml::Xml::Schema::Xsd.parse(
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
    "<xs:element name=\"c\">" \
    '<xs:keyref name="r" refer="k"/></xs:element></xs:schema>',
  )
  Array(minimal.element.first.keyref).first.refer.is_a?(String)
rescue StandardError
  false
end

RSpec.describe "identity constraints (key/keyref/unique)" do
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }
  let(:xsd_source) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
        <xs:element name="catalog">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="item" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:attribute name="code" type="xs:string"/>
                </xs:complexType>
              </xs:element>
              <xs:element name="ref" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:attribute name="target" type="xs:string"/>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
          <xs:key name="itemKey">
            <xs:selector xpath="item"/>
            <xs:field xpath="@code"/>
          </xs:key>
          <xs:keyref name="refKey" refer="itemKey">
            <xs:selector xpath="ref"/>
            <xs:field xpath="@target"/>
          </xs:keyref>
        </xs:element>
      </xs:schema>
    XSD
  end

  let!(:registered) { schema }
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ nil => schema })
  end
  let(:validator) do
    Lutaml::Xsd::Validation::Validator.new(repository, config: config)
  end
  let(:config) do
    {
      "validation" => {
        "features" => { "engine_validation" => false },
      },
    }
  end

  it "accepts keyrefs that resolve" do
    result = validator.validate(
      '<catalog><item code="a"/><ref target="a"/></catalog>',
    )

    expect(result.valid?).to be(true)
  end

  it "rejects dangling keyrefs", if: REFER_MAPPED do
    result = validator.validate(
      '<catalog><item code="a"/><ref target="zzz"/></catalog>',
    )

    expect(result.valid?).to be(false)
    expect(result.errors.map(&:code)).to include("keyref_violation")
  end

  it "degrades to valid while keyref refer is unmapped", unless: REFER_MAPPED do
    result = validator.validate(
      '<catalog><item code="a"/><ref target="zzz"/></catalog>',
    )

    codes = result.errors.map(&:code)
    expect(codes).not_to include("keyref_violation")
  end

  it "rejects duplicate key values" do
    result = validator.validate(
      '<catalog><item code="a"/><item code="a"/><ref target="a"/></catalog>',
    )

    expect(result.valid?).to be(false)
    expect(result.errors.map(&:code)).to include("duplicate_key_violation")
  end

  context "with an element-keyed field and no xsi:type override" do
    let(:xsd_source) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="catalog">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="item" maxOccurs="unbounded">
                  <xs:complexType>
                    <xs:sequence>
                      <xs:element name="code" type="xs:string"/>
                    </xs:sequence>
                  </xs:complexType>
                </xs:element>
              </xs:sequence>
            </xs:complexType>
            <xs:unique name="codeKey">
              <xs:selector xpath="item"/>
              <xs:field xpath="code"/>
            </xs:unique>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "evaluates the field through the declaration type" do
      result = validator.validate(
        "<catalog>" \
        "<item><code>a</code></item>" \
        "<item><code>a</code></item>" \
        "</catalog>",
      )

      codes = result.errors.map(&:code)
      expect(codes).not_to include("rule_execution_error")
      expect(codes).to include("duplicate_unique_violation")
    end
  end

  context "with same lexicals in disjoint value spaces" do
    let(:xsd_source) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="uid" maxOccurs="unbounded"/>
              </xs:sequence>
            </xs:complexType>
            <xs:unique name="uuid">
              <xs:selector xpath=".//uid"/>
              <xs:field xpath="."/>
            </xs:unique>
          </xs:element>
          <xs:element name="uid" type="xs:anyType"/>
        </xs:schema>
      XSD
    end

    it "keeps boolean and decimal distinct" do
      result = validator.validate(
        '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
        ' xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
        "<uid xsi:type=\"xs:boolean\">1</uid>" \
        "<uid xsi:type=\"xs:decimal\">1</uid></root>",
      )

      codes = result.errors.map(&:code)
      expect(codes).not_to include("duplicate_unique_violation")
    end

    it "keeps float and decimal distinct" do
      result = validator.validate(
        '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
        ' xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
        "<uid xsi:type=\"xs:float\">1</uid>" \
        "<uid xsi:type=\"xs:decimal\">1</uid></root>",
      )

      codes = result.errors.map(&:code)
      expect(codes).not_to include("duplicate_unique_violation")
    end

    it "keeps decimal and integer unified" do
      result = validator.validate(
        '<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
        ' xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
        "<uid xsi:type=\"xs:integer\">1</uid>" \
        "<uid xsi:type=\"xs:decimal\">1</uid></root>",
      )

      expect(result.errors.map(&:code))
        .to include("duplicate_unique_violation")
    end
  end

  context "with fields supplied by the declaration" do
    let(:xsd_source) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="uid" maxOccurs="unbounded"/>
              </xs:sequence>
            </xs:complexType>
            <xs:unique name="uuid">
              <xs:selector xpath=".//uid"/>
              <xs:field xpath="@val"/>
            </xs:unique>
          </xs:element>
          <xs:element name="uid">
            <xs:complexType>
              <xs:attribute name="val" type="xs:string" default="test"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "counts an absent defaulted attribute as its default" do
      result = validator.validate(
        '<root><uid val="test"/><uid/></root>',
      )

      expect(result.errors.map(&:code))
        .to include("duplicate_unique_violation")
    end
  end

  context "with unprefixed selectors in a namespaced schema" do
    let(:xsd_source) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="myNS" xmlns="myNS">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="kid" maxOccurs="unbounded"/>
              </xs:sequence>
            </xs:complexType>
            <xs:key name="kuuid">
              <xs:selector xpath=".//kid"/>
              <xs:field xpath="@val"/>
            </xs:key>
          </xs:element>
          <xs:element name="kid">
            <xs:complexType>
              <xs:attribute name="val" type="xs:string"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "collects key rows from qualified instances" do
      result = validator.validate(
        '<myNS:root xmlns:myNS="myNS">' \
        "<myNS:kid val=\"1\"/><myNS:kid val=\"1\"/></myNS:root>",
      )

      expect(result.errors.map(&:code))
        .to include("duplicate_key_violation")
    end
  end
end
