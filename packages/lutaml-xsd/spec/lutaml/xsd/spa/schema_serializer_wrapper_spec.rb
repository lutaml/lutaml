# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "moxml"
require "tempfile"

RSpec.describe Lutaml::Xsd::Spa::SchemaSerializer do
  subject(:serializer) { described_class.new(nil, { verbose: false }) }

  let(:xs) { { "xs" => "http://www.w3.org/2001/XMLSchema" } }

  let(:schema_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:tns="http://example.com/test"
                 targetNamespace="http://example.com/test">
        <xs:complexType name="Address">
          <xs:sequence>
            <xs:element name="street" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
        <xs:element name="address" type="tns:Address"/>
      </xs:schema>
    XML
  end

  let(:schema_path) do
    file = Tempfile.new(["characterization", ".xsd"])
    file.write(schema_xml)
    file.close
    file.path
  end

  after do
    FileUtils.rm_f(schema_path)
  end

  def wrapper_document(path)
    Moxml::Context.new.parse(File.read(path))
  end

  describe "#create_type_wrapper_xsd" do
    it "wraps a schema-level type in a synthetic root element" do
      wrapper_path = nil
      wrapper_path = serializer.create_type_wrapper_xsd("Address", schema_path)
      wrapper = File.read(wrapper_path)
      doc = wrapper_document(wrapper_path)

      expect(doc.at_xpath("//xs:schema", xs)).not_to be_nil
      added = doc.at_xpath("//xs:element[@name='_diagram_root_Address']", xs)
      expect(added).not_to be_nil
      expect(added["type"]).to eq("tns:Address")
      expect(wrapper).to include("complexType")
      expect(wrapper).to include('name="street"')
    ensure
      FileUtils.rm_f(wrapper_path)
    end

    it "returns the original path when no xs:schema exists" do
      no_schema = Tempfile.new(["no-schema", ".xsd"])
      no_schema.write("<not-a-schema/>")
      no_schema.close

      expect(serializer.create_type_wrapper_xsd("Address", no_schema.path))
        .to eq(no_schema.path)
    ensure
      no_schema.unlink
    end
  end

  describe "#resolve_type_prefix" do
    it "prefixes types defined in the schema's targetNamespace" do
      doc = Moxml::Context.new.parse(schema_xml)

      expect(serializer.resolve_type_prefix("Address", doc, xs))
        .to eq("tns:Address")
    end

    it "returns the bare name for unknown types" do
      doc = Moxml::Context.new.parse(schema_xml)

      expect(serializer.resolve_type_prefix("xs:string", doc, xs))
        .to eq("xs:string")
    end
  end
end
