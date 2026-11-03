# frozen_string_literal: true

require "spec_helper"
require "json"
require "lutaml/xsd"
require "lutaml/xsd/json_schema_exporter"

RSpec.describe Lutaml::Xsd::JsonSchemaExporter do
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }
  let(:exported) { described_class.new(schema).export }

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
            <xs:element name="email" type="xs:string" maxOccurs="unbounded" minOccurs="0"/>
            <xs:element name="status">
              <xs:simpleType>
                <xs:restriction base="xs:string">
                  <xs:enumeration value="active"/>
                  <xs:enumeration value="inactive"/>
                </xs:restriction>
              </xs:simpleType>
            </xs:element>
          </xs:sequence>
          <xs:attribute name="id" type="xs:string" use="required"/>
          <xs:attribute name="mode" type="xs:string" fixed="auto"/>
        </xs:complexType>
      </xs:schema>
    XSD
  end

  it "emits a draft 2020-12 document with the target namespace as $id" do
    expect(exported["$schema"]).to eq(described_class::DRAFT)
    expect(exported["$id"]).to eq("http://example.com/test")
  end

  it "defines top-level complex types under $defs" do
    expect(exported["$defs"]).to include("t_person")
    expect(exported["$defs"]["t_person"]["type"]).to eq("object")
  end

  it "maps sequence elements to properties with required entries" do
    person = exported["$defs"]["t_person"]

    expect(person["properties"].keys).to include("name", "age", "email", "status")
    expect(person["required"]).to contain_exactly("name", "status", "id")
  end

  it "maps repeated elements to arrays" do
    email = exported["$defs"]["t_person"]["properties"]["email"]

    expect(email["type"]).to eq("array")
    expect(email["items"]["type"]).to eq("string")
  end

  it "maps enumeration restrictions to enum" do
    status = exported["$defs"]["t_person"]["properties"]["status"]

    expect(status["enum"]).to eq(%w[active inactive])
  end

  it "maps builtin types and required/fixed attributes" do
    person = exported["$defs"]["t_person"]

    expect(person["properties"]["age"]["type"]).to eq("integer")
    expect(person["properties"]["id"]["type"]).to eq("string")
    expect(person["properties"]["mode"]["const"]).to eq("auto")
  end

  it "references elements as oneOf" do
    expect(exported["oneOf"]).to include("$ref" => "#/$defs/person")
  end

  it "serializes to JSON" do
    json = described_class.new(schema).to_json
    parsed = JSON.parse(json)

    expect(parsed["$schema"]).to eq(described_class::DRAFT)
  end
end
