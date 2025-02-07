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

    context "correctly parses xml document" do
      let(:xml_file_path) { fixtures_path("test.xml") }
      let(:root_name) { "Person" }

      it "parses xml file into Lutaml::Model::Serializable object" do
        parsed = parse
        expect(parsed).to be_instance_of(Person)
      end

      it "expect to read the xml file" do
        input_xml = File.read(xml_file_path)
        formatted_xml = Nokogiri::XML(parse.to_xml).root.to_xml
        expect(formatted_xml).to be_equivalent_to(input_xml)
      end
    end
  end
end
