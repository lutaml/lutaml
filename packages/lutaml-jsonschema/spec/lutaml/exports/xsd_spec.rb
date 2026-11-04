# frozen_string_literal: true

require "spec_helper"
require "rexml/document"

RSpec.describe Lutaml::Jsonschema::Exports::Xsd do
  def schema_set_from(hash, name: "demo")
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add(name, Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash)))
    set
  end

  def render(hash)
    described_class.new(schema_set_from(hash)).render
  end

  def parse_xml(xml)
    REXML::Document.new(xml)
  end

  it "emits an xs:schema with the target namespace" do
    doc = parse_xml(render("type" => "object"))
    root = doc.root

    expect(root.name).to eq("schema")
    expect(root.attributes["targetNamespace"]).to eq("urn:lutaml:jsonschema")
    expect(root.namespaces["xs"]).to eq("http://www.w3.org/2001/XMLSchema")
  end

  it "renders object properties with scalar types and optionality" do
    doc = parse_xml(render(
                      "type" => "object",
                      "required" => %w[name],
                      "properties" => {
                        "name" => { "type" => "string" },
                        "age" => { "type" => "integer" },
                      },
                    ))
    root = doc.root

    name = REXML::XPath.first(root, "//xs:element[@name='name']")
    age = REXML::XPath.first(root, "//xs:element[@name='age']")

    expect(name.attributes["type"]).to eq("xs:string")
    expect(name.attributes["minOccurs"]).to be_nil
    expect(age.attributes["minOccurs"]).to eq("0")
  end

  it "renders boolean items without supplying a bogus element type" do
    doc = parse_xml(render(
                      "type" => "object",
                      "properties" => {
                        "tags" => { "type" => "array", "items" => false },
                      },
                    ))
    element = doc.root.get_elements("//xs:element").find do |e|
      e.attributes["name"] == "tags"
    end

    expect(element.attributes["type"]).to be_nil
  end

  it "leaves boolean property schemas untyped" do
    doc = parse_xml(render(
                      "type" => "object",
                      "properties" => { "flag" => true },
                    ))
    element = doc.root.get_elements("//xs:element").find do |e|
      e.attributes["name"] == "flag"
    end

    expect(element.attributes["type"]).to be_nil
  end

  it "renders arrays as unbounded repeated items" do
    doc = parse_xml(render(
                      "type" => "object",
                      "properties" => { "tags" => { "type" => "array",
                                                    "items" => { "type" => "string" } } },
                    ))

    tags = REXML::XPath.first(doc.root, "//xs:element[@name='tags']")
    expect(tags.attributes["maxOccurs"]).to eq("unbounded")
    expect(tags.attributes["type"]).to eq("xs:string")
  end

  it "renders definitions as named types and refs as tns references" do
    output = render(
      "definitions" => {
        "address" => { "type" => "object",
                       "properties" => { "city" => { "type" => "string" } } },
      },
      "type" => "object",
      "properties" => { "address" => { "$ref" => "#/definitions/address" } },
    )
    doc = parse_xml(output)

    type = REXML::XPath.first(doc.root,
                              "//xs:complexType[@name='address']")
    member = REXML::XPath.first(
      doc.root, "//xs:element[@name='address']"
    )
    expect(type).not_to be_nil
    expect(member.attributes["type"]).to eq("tns:address")
  end

  it "renders enums as simpleType restrictions" do
    doc = parse_xml(render(
                      "type" => "object",
                      "properties" => { "status" => { "enum" => %w[a b] } },
                    ))

    values = REXML::XPath.match(doc.root, "//xs:enumeration")
      .map { |node| node.attributes["value"] }
    expect(values).to contain_exactly("a", "b")
  end

  it "exports through the CLI with --format xsd" do
    expect do
      Lutaml::Jsonschema::Cli.start(
        ["export", fixture_path("person.json"), "--format", "xsd"],
      )
    end.to output(/xs:schema/).to_stdout
  end
end
