# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/unique_particle_attribution"

RSpec.describe Lutaml::Xsd::Validation::UniqueParticleAttribution do
  def findings_for(xsd)
    schema = Lutaml::Xml::Schema::Xsd.parse(xsd)
    described_class.new(schema).findings
  end

  it "reports an optional element followed by the same element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a" minOccurs="0"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings.map(&:code)).to eq(["upa_violation"])
    expect(findings.first.message).to include("'a'")
  end

  it "reports a choice with duplicate alternatives" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:choice>
              <xs:element name="a"/>
              <xs:element name="a"/>
            </xs:choice>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports an optional choice whose names overlap the next element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:choice minOccurs="0">
                <xs:element name="a"/>
                <xs:element name="b"/>
              </xs:choice>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports an unbounded element followed by itself" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a" maxOccurs="unbounded"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "accepts two required occurrences of the same element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).to be_empty
  end

  it "accepts an optional element followed by a different element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="a" minOccurs="0"/>
              <xs:element name="b"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).to be_empty
  end

  it "reports a wildcard overlapping a sibling element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:any namespace="##any" minOccurs="0"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports ambiguity across a repeated nested group" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:sequence minOccurs="0">
                <xs:element name="a"/>
              </xs:sequence>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "reports ambiguity through an expanded group reference" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:group name="ga">
          <xs:sequence>
            <xs:element name="a" minOccurs="0"/>
          </xs:sequence>
        </xs:group>
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:group ref="ga"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "accepts a group reference followed by a different element" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:group name="gb">
          <xs:sequence>
            <xs:element name="b"/>
          </xs:sequence>
        </xs:group>
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:group ref="gb"/>
              <xs:element name="a"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).to be_empty
  end

  it "reports a choice of head and substitution-group member" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="h" type="xs:string"/>
        <xs:element name="m1" type="xs:string" substitutionGroup="h"/>
        <xs:element name="r">
          <xs:complexType>
            <xs:choice>
              <xs:element name="h"/>
              <xs:element name="m1"/>
            </xs:choice>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end

  it "accepts a substitution member followed by its head, both required" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="h" type="xs:string"/>
        <xs:element name="m1" type="xs:string" substitutionGroup="h"/>
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="m1"/>
              <xs:element name="h"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).to be_empty
  end

  it "reports an optional head before a substitution-group member" do
    findings = findings_for(<<~XSD)
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="h" type="xs:string"/>
        <xs:element name="m1" type="xs:string" substitutionGroup="h"/>
        <xs:element name="r">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="h" minOccurs="0"/>
              <xs:element name="m1"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD

    expect(findings).not_to be_empty
  end
end

RSpec.describe "UPA validation wiring" do
  let(:ambiguous_schema_xml) do
    <<~XSD
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="r">
          <xs:complexType>
            <xs:choice>
              <xs:element name="a"/>
              <xs:element name="a"/>
            </xs:choice>
          </xs:complexType>
        </xs:element>
      </xs:schema>
    XSD
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(ambiguous_schema_xml) }
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
  let(:config_overrides) { {} }
  let(:config) do
    Lutaml::Xsd::Validation::ValidationConfiguration.new(
      "validation" => { "features" => { "validate_upa" => true }.merge(config_overrides) },
    )
  end

  def run_job
    Lutaml::Xsd::Validation::ValidationJob.new(
      xml_content: "<r><a/></r>",
      repository: repository,
      rule_registry: Lutaml::Xsd::Validation::RuleRegistry.default(config),
      config: config,
    ).execute
  end

  it "surfaces schema UPA findings as warnings" do
    result = run_job

    upa_warnings = result.warnings.select { |w| w.code == "upa_violation" }
    expect(upa_warnings).not_to be_empty
  end

  it "keeps warnings from failing the instance" do
    result = run_job

    expect(result.valid?).to be(true)
  end

  context "when validate_upa is disabled" do
    let(:config_overrides) { { "validate_upa" => false } }

    it "emits no UPA warnings" do
      result = run_job

      upa_warnings = result.warnings.select { |w| w.code == "upa_violation" }
      expect(upa_warnings).to be_empty
    end
  end
end
