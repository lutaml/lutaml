require "spec_helper"
require "canon"

RSpec.describe Lutaml::Xml::Parsers::Xml do
  describe ".parse" do
    subject(:parse) { described_class.parse(xml_file_path) }

    before do
      described_class.load_schema(schema, root_name) unless defined?(Person)
    end

    let(:schema) do
      File.read(fixtures_path("schema.xml"))
    end

    context "correctly parses xml document" do
      let(:xml_file_path) { fixtures_path("test.xml") }
      let(:root_name) { "Person" }

      it "parses xml file into Lutaml::Model::Serializable object" do
        parsed = parse
        expect(parsed).to be_instance_of(Person)
      end

      it "outputs xml as same as the xml file it reads" do
        input_xml = File.read(xml_file_path)
        formatted_xml = Nokogiri::XML(parse.to_xml).root.to_xml
        expect(formatted_xml).to be_xml_equivalent_to(input_xml)
      end

      it "parses xml file and able to output hash" do
        parsed = parse
        result = JSON.parse(parsed.to_json)

        expect(result).to include(
          "age" => 50,
          "first_name" => ["John"],
          "last_name" => ["Doe"],
          "hobby" => ["Singing", "Dancing"],
          "address" => [
            include(
              "city" => ["London"],
              "zip" => ["E1 6AN"],
            ),
          ],
        )
        expect(result["address"].first["content"]).to include(
          "\n    Oxford Street\n    ",
        )
      end
    end
  end
end
