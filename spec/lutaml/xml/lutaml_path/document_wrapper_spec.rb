# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xml::LutamlPath::DocumentWrapper do
  describe ".parse" do
    subject(:lutaml_path) { described_class.new(Lutaml::Xml::Parsers::Xml.parse(xml_file_path)) }

    context "#serialize_document" do
      let(:xml_file_path) { fixtures_path("test.xml") }

      before(:each) do
        Lutaml::Xml::Parsers::Xml.load_schema(schema, root_name)
      end

      let(:schema) do
        File.read(fixtures_path("schema.xml"))
      end

      let(:root_name) { "Person" }

      let(:serialized_document) { lutaml_path.serialized_document }

      let(:expected_serialized_hash) do
        {
          "Address" => {
            "City" => "London",
            "ZIP" => "E1 6AN",
            "content" => ["Oxford Street"]
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
