# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation"
require "tmpdir"
require "lutaml/xsd/conformance/runner"

RSpec.describe "wildcard scoping, anyType and default content" do
  def run_pipeline(schema_xml, instance_xml, extra_schemas = {})
    schema = Lutaml::Xml::Schema::Xsd.parse(schema_xml)
    schemas = { schema.target_namespace.to_s.match?(/\S/) ? schema.target_namespace : nil => schema }
    schemas.merge!(extra_schemas)
    config = Lutaml::Xsd::Validation::ValidationConfiguration.new
    job = Lutaml::Xsd::Validation::ValidationJob.new(
      xml_content: instance_xml,
      repository: Lutaml::Xsd::Conformance::Runner::Repository.new(schemas),
      rule_registry: Lutaml::Xsd::Validation::RuleRegistry.default(config),
      config: config,
    )
    job.execute
  end

  def codes(result)
    (result.errors + result.warnings).map(&:code)
  end

  describe "processContents=skip wildcards" do
    it "suppresses all assessment of the matched subtree" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:choice minOccurs="0" maxOccurs="unbounded">
                <xs:any namespace="##any" processContents="skip"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
          <xs:element name="strict" type="strictType"/>
          <xs:complexType name="strictType">
            <xs:attribute name="att" type="xs:integer" use="required"/>
          </xs:complexType>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root><strict/></root>")

      expect(codes(result)).not_to include("required_attribute_missing")
      expect(codes(result)).not_to include("unexpected_element_in_sequence")
      expect(codes(result)).not_to include("choice_min_occurs_violation")
    end
  end

  describe "processContents=strict wildcards" do
    it "accepts a matched child whose xsi:type supplies the definition" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="foo">
            <xs:sequence>
              <xs:element name="a"/>
              <xs:any namespace="##any" processContents="strict"
                      minOccurs="0" maxOccurs="unbounded"/>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="foo" type="foo"/>
        </xs:schema>
      XSD

      instance = <<~XML
        <foo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <a/>
          <b xsi:type="xs:string">abc</b>
        </foo>
      XML

      result = run_pipeline(schema, instance)

      expect(codes(result)).not_to include("wildcard_undeclared_element")
    end
  end

  describe "xs:anyType elements" do
    it "accepts any attributes" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="t" xmlns:t="t" elementFormDefault="qualified">
          <xs:complexType name="array">
            <xs:sequence minOccurs="0">
              <xs:element name="item" type="xs:anyType" form="unqualified"/>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="array" type="t:array"/>
        </xs:schema>
      XSD

      instance = <<~XML
        <t:Array xmlns:t="t">
          <item foreign:att="1" xmlns:foreign="f"/>
        </t:Array>
      XML

      result = run_pipeline(schema, instance)

      expect(codes(result)).not_to include("unexpected_attribute")
    end
  end

  describe "xml namespace attribute references" do
    it "resolves xml:base and satisfies its required use" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   elementFormDefault="qualified">
          <xs:import namespace="http://www.w3.org/XML/1998/namespace"/>
          <xs:element name="root">
            <xs:complexType>
              <xs:attribute ref="xml:base" use="required"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, '<root xml:base="a"/>')

      expect(codes(result)).not_to include("required_attribute_missing")
      expect(codes(result)).not_to include("unexpected_attribute")
    end
  end

  describe "fixed and default content values" do
    it "validates an empty element against its fixed value" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="number" type="xs:integer" fixed="123"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root><number/></root>")

      expect(codes(result)).not_to include("type_validation_error")
    end

    it "validates an empty element against its default value" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="employee" type="xs:int" default="1"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root><employee/></root>")

      expect(codes(result)).not_to include("type_validation_error")
    end

    it "compares fixed attribute values in the value space" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:attribute name="att" type="xs:integer" fixed="  123  "/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, '<doc att="123"/>')

      expect(codes(result)).not_to include("fixed_attribute_value_mismatch")
    end

    it "checks the fixed value of a type-less element" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="a" fixed="fixed_value"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root><a>not fixed</a></root>")

      expect(codes(result)).to include("fixed_content_value_mismatch")
    end

    it "checks the fixed value of a complex-typed element" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root" fixed="abc">
            <xs:complexType mixed="true">
              <xs:sequence minOccurs="0">
                <xs:element name="e1"/>
                <xs:element name="e2"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root>not_fixed</root>")

      expect(codes(result)).to include("fixed_content_value_mismatch")
    end
  end

  describe "undeclared root with an xsi:type override" do
    it "is assessed against the named type instead of rejected" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="t">
            <xs:attribute name="a" type="xs:string"/>
          </xs:complexType>
        </xs:schema>
      XSD

      result = run_pipeline(schema, '<doc xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="t" a="x"/>')

      expect(codes(result)).not_to include("element_not_allowed")
    end

    it "still rejects an undeclared root whose override does not resolve" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="t">
            <xs:attribute name="a" type="xs:string"/>
          </xs:complexType>
        </xs:schema>
      XSD

      result = run_pipeline(schema, '<doc xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="zzz"/>')

      expect(codes(result)).to include("element_not_allowed")
    end
  end

  describe "xsi:type overrides naming built-ins" do
    it "resolves to the built-in type" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="uid" type="xs:anyType"/>
        </xs:schema>
      XSD

      instance = <<~XML
        <uid xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:type="xs:int">123</uid>
      XML

      result = run_pipeline(schema, instance)

      expect(codes(result)).not_to include("xsi_type_unknown")
      expect(codes(result)).not_to include("xsi_type_not_derived")
    end
  end

  describe "occurrence counting abstentions" do
    it "abstains when a wildcard can absorb the counted children" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="test">
            <xs:complexType>
              <xs:sequence>
                <xs:any namespace="##any" processContents="strict"/>
                <xs:element name="element1"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema,
                            "<test><element1/><element1/></test>")

      expect(codes(result)).not_to include("max_occurs_violation")
    end

    it "abstains for same-named sibling declarations" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="e"/>
                <xs:element name="e"/>
                <xs:element name="e"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root><e/><e/><e/></root>")

      expect(codes(result)).not_to include("max_occurs_violation")
    end

    it "skips child minimums of an optional container" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence minOccurs="0">
                <xs:element name="e1"/>
                <xs:element name="e2"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<root/>")

      expect(codes(result)).not_to include("min_occurs_violation")
    end
  end

  describe "xs:all occurrence bounds" do
    it "accepts the empty sequence for an optional xs:all" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="elt1">
            <xs:complexType>
              <xs:all minOccurs="0">
                <xs:element name="elt2"/>
                <xs:element name="elt3"/>
              </xs:all>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<elt1/>")

      expect(codes(result)).not_to include("sequence_min_occurs_violation")
      expect(codes(result)).not_to include("min_occurs_violation")
    end
  end

  describe "instance schema-location hints" do
    let(:entry_schema) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:anyAttribute namespace="##any"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end
    let(:companion_schema) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="companion">
          <xs:attribute name="known" type="xs:string"/>
        </xs:schema>
      XSD
    end

    def write_fixtures
      dir = Dir.mktmpdir
      File.write(File.join(dir, "entry.xsd"), entry_schema)
      File.write(File.join(dir, "companion.xsd"), companion_schema)
      instance = <<~XML
        <root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:noNamespaceSchemaLocation="entry.xsd"
              xsi:schemaLocation="companion companion.xsd"
              xmlns:c="companion" c:known="x"/>
      XML
      instance_path = File.join(dir, "instance.xml")
      File.write(instance_path, instance)
      [dir, instance_path, instance]
    end

    it "follows xsi hints when the instance base is given" do
      dir, _path, instance = write_fixtures

      schema = Lutaml::Xml::Schema::Xsd.parse(entry_schema, location: File.join(dir, "entry.xsd"))
      config = Lutaml::Xsd::Validation::ValidationConfiguration.new
      job = Lutaml::Xsd::Validation::ValidationJob.new(
        xml_content: instance,
        repository: Lutaml::Xsd::Conformance::Runner::Repository.new({ nil => schema }),
        rule_registry: Lutaml::Xsd::Validation::RuleRegistry.default(config),
        config: config,
        instance_base: dir,
      )

      expect(codes(job.execute)).not_to include("wildcard_undeclared_attribute")
      expect(codes(job.execute)).not_to include("unexpected_attribute")
    end

    it "ignores hints without an instance base" do
      dir, _path, instance = write_fixtures

      schema = Lutaml::Xml::Schema::Xsd.parse(entry_schema, location: File.join(dir, "entry.xsd"))
      config = Lutaml::Xsd::Validation::ValidationConfiguration.new
      job = Lutaml::Xsd::Validation::ValidationJob.new(
        xml_content: instance,
        repository: Lutaml::Xsd::Conformance::Runner::Repository.new({ nil => schema }),
        rule_registry: Lutaml::Xsd::Validation::RuleRegistry.default(config),
        config: config,
      )

      expect(codes(job.execute)).to include("wildcard_undeclared_attribute")
    end
  end

  describe "built-in ID uniqueness" do
    let(:id_schema) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="root">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="item" maxOccurs="unbounded"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
          <xs:element name="item">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="key" type="xs:ID"/>
              </xs:sequence>
              <xs:attribute name="ref" type="xs:ID"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "rejects a repeated ID element value" do
      result = run_pipeline(
        id_schema,
        "<root><item><key>a</key></item><item><key>a</key></item></root>",
      )

      expect(codes(result)).to include("id_duplicate_violation")
    end

    it "rejects a repeated ID attribute value" do
      result = run_pipeline(
        id_schema,
        '<root><item ref="a"><key>a</key></item></root>',
      )

      expect(codes(result)).to include("id_duplicate_violation")
    end

    it "accepts distinct ID values" do
      result = run_pipeline(
        id_schema,
        "<root><item><key>a</key></item><item><key>b</key></item></root>",
      )

      expect(codes(result)).not_to include("id_duplicate_violation")
    end
  end

  describe "attribute form defaults" do
    it "accepts a qualified instance attribute for a form=qualified declaration" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="t" xmlns:t="t" elementFormDefault="qualified">
          <xs:complexType name="attRef">
            <xs:attribute name="ca1" form="qualified"/>
          </xs:complexType>
          <xs:element name="doc">
            <xs:complexType>
              <xs:choice>
                <xs:element name="elem" type="t:attRef"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(
        schema,
        '<t:doc xmlns:t="t"><t:elem t:ca1="123"/></t:doc>',
      )

      expect(codes(result)).not_to include("unexpected_attribute")
    end

    it "rejects an unqualified instance attribute for a form=qualified declaration" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="t" xmlns:t="t" elementFormDefault="qualified">
          <xs:complexType name="attRef">
            <xs:attribute name="ca1" form="qualified"/>
          </xs:complexType>
          <xs:element name="doc">
            <xs:complexType>
              <xs:choice>
                <xs:element name="elem" type="t:attRef"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(
        schema,
        '<t:doc xmlns:t="t"><t:elem ca1="123"/></t:doc>',
      )

      expect(codes(result)).to include("unexpected_attribute")
    end

    it "honors form=unqualified over attributeFormDefault=qualified" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="t" xmlns:t="t" elementFormDefault="qualified"
                   attributeFormDefault="qualified">
          <xs:attributeGroup name="attG">
            <xs:attribute name="aga1" form="unqualified"/>
          </xs:attributeGroup>
          <xs:complexType name="attRef">
            <xs:attributeGroup ref="t:attG"/>
          </xs:complexType>
          <xs:element name="doc">
            <xs:complexType>
              <xs:choice>
                <xs:element name="elem" type="t:attRef"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(
        schema,
        '<t:doc xmlns:t="t"><t:elem t:aga1="123"/></t:doc>',
      )

      expect(codes(result)).to include("unexpected_attribute")
    end

    it "accepts attributeGroup members qualified through the group declaration" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="t" xmlns:t="t">
          <xs:attributeGroup name="attG">
            <xs:attribute name="aga1" default="abc" form="qualified"/>
            <xs:attribute name="aga2"/>
          </xs:attributeGroup>
          <xs:complexType name="attRef">
            <xs:attribute name="ca1"/>
            <xs:attributeGroup ref="t:attG"/>
          </xs:complexType>
          <xs:element name="doc">
            <xs:complexType>
              <xs:choice>
                <xs:element name="elem" type="t:attRef" form="qualified"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(
        schema,
        '<t:doc xmlns:t="t"><t:elem t:aga1="abc" ca1="123"/></t:doc>',
      )

      expect(codes(result)).not_to include("unexpected_attribute")
    end
  end

  describe "pattern facets" do
    it "matches a whitespace-only value against a whitespace pattern" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:simpleType>
              <xs:restriction base="xs:string">
                <xs:pattern value="[\\n]"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<doc>\n</doc>")

      expect(codes(result)).not_to include("pattern_mismatch")
    end

    it "treats multiple patterns on one step as alternatives" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:simpleType>
              <xs:restriction base="xs:string">
                <xs:pattern value="[abc]+"/>
                <xs:pattern value="[123]+"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<doc>112233123</doc>")

      expect(codes(result)).not_to include("pattern_mismatch")
    end

    it "reports only when no pattern on the step matches" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:simpleType>
              <xs:restriction base="xs:string">
                <xs:pattern value="[abc]+"/>
                <xs:pattern value="[123]+"/>
              </xs:restriction>
            </xs:simpleType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, "<doc>x</doc>")

      expect(codes(result)).to include("pattern_mismatch")
    end

    it "treats multiple patterns on an attribute restriction as alternatives" do
      schema = <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:attribute name="att">
                <xs:simpleType>
                  <xs:restriction base="xs:string">
                    <xs:pattern value="[abc]+"/>
                    <xs:pattern value="[123]+"/>
                  </xs:restriction>
                </xs:simpleType>
              </xs:attribute>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD

      result = run_pipeline(schema, '<doc att="112233123"/>')

      expect(codes(result)).not_to include("attribute_pattern_violation")
    end
  end

  describe "derivation bodies that are bare group references" do
    let(:schema) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="base">
            <xs:sequence>
              <xs:element name="old"/>
            </xs:sequence>
          </xs:complexType>
          <xs:group name="x">
            <xs:sequence>
              <xs:element name="x1"/>
              <xs:element name="x2"/>
            </xs:sequence>
          </xs:group>
          <xs:group name="y">
            <xs:choice>
              <xs:element name="y1"/>
              <xs:element name="y2"/>
            </xs:choice>
          </xs:group>
          <xs:group name="G">
            <xs:choice>
              <xs:group ref="x"/>
              <xs:group ref="y"/>
            </xs:choice>
          </xs:group>
          <xs:element name="elem">
            <xs:complexType>
              <xs:complexContent>
                <xs:restriction base="base">
                  <xs:group ref="G" minOccurs="1"/>
                </xs:restriction>
              </xs:complexContent>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    it "enforces the restriction's group model" do
      result = run_pipeline(schema, "<elem><y1/></elem>")

      expect(codes(result)).not_to include("unexpected_element_in_sequence")
    end

    it "rejects content outside the restriction's group model" do
      result = run_pipeline(schema, "<elem><old/></elem>")

      expect(result.valid?).to be(false)
    end

    it "counts a group's sequence members as one branch" do
      result = run_pipeline(schema, "<elem><x1/><x2/></elem>")

      expect(codes(result)).not_to include("choice_max_occurs_violation")
    end

    it "rejects a second branch when the group ref allows one" do
      result = run_pipeline(schema, "<elem><x1/><x2/><x1/><x2/></elem>")

      expect(codes(result)).to include("choice_max_occurs_violation")
    end
  end
end
