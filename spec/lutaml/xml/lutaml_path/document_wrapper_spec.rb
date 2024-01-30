# frozen_string_literal: true

require "spec_helper"

require_relative "../test_classes/person"
require_relative "../test_classes/address"

RSpec.describe Lutaml::Xml::LutamlPath::DocumentWrapper do
  describe ".parse" do
    before(:all) do
      Lutaml::Xml::Parsers::Xml.set_document(Person)
    end

    subject(:lutaml_path) { described_class.new(parsed_xml) }

    context "#serialize_document" do
      let(:xml_file) { fixtures_path("test.xml") }

      let(:parsed_xml) do
        Lutaml::Xml::Parsers::Xml.parse(xml_file)
      end

      subject(:serialized_document) { lutaml_path.serialized_document }

      let(:expected_serialized_hash) do
        {
          "Address" => {
            "City" => "London",
            "ZIP" => "E1 6AN",
            "street" => ["Oxford Street", "", ""]
          },
          "FirstName" => "John",
          "LastName" => "Doe",
          "Hobby" => ["Singing", "Dancing"],
        }
      end

      it "should correctly serialize to hash" do
        expect(serialized_document).to eq(expected_serialized_hash)
      end
    end
  end
end
