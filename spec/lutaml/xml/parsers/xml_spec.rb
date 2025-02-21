require "spec_helper"
require "equivalent-xml"

RSpec.describe Lutaml::Xml::Parsers::Xml do
  describe ".parse" do
    subject(:parse) { described_class.parse(xml_file_path) }

    before(:each) do
      Lutaml::Xml::Parsers::Xml.load_schema(schema, root_name)
    end

    let(:schema) do
      File.read(fixtures_path("schema.xml"))
    end

    let(:expected_hash) do
      {
        "age" => 50,
        "first_name" => ["John"],
        "last_name" => ["Doe"],
        "hobby" => ["Singing", "Dancing"],
        "address" => [
          {
            "city" => ["London"],
            "zip" => ["E1 6AN"],
            "content" => [
              "\n    Oxford Street\n    ",
              "\n    ", "\n  "
            ],
          },
        ],
      }
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
        expect(formatted_xml).to be_equivalent_to(input_xml)
      end

      it "parses xml file and able to output hash" do
        parsed = parse
        expect(JSON.parse(parsed.to_json)).to eq(expected_hash)
      end
    end
  end
end
