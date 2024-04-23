require "spec_helper"
require "shale"
require "lutaml/xml/mapper"
require "equivalent-xml"

# require_relative "../test_classes/person"
# require_relative "../test_classes/address"

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

      it "parses xml file into Lutaml::Uml::Node::Document object" do
        parsed = parse
        expect(parsed).to be_instance_of(Person)
      end

      it "expect to read the xml file" do
        input_xml = File.read(xml_file_path)

        expect(parse.to_xml(pretty: true)).to be_equivalent_to(input_xml)
      end
    end
  end
end
