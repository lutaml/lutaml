require "spec_helper"
require "shale"
require "lutaml/xml/mapper"

require_relative "../test_classes/person"
require_relative "../test_classes/address"

RSpec.describe Lutaml::Xml::Parsers::Xml do
  describe ".parse" do
    subject(:parse) { described_class.parse(xml_file_path) }

    before(:all) do
      Lutaml::Xml::Parsers::Xml.set_document(Person)
    end

    context "correctly parses xml document" do
      let(:xml_file_path) { fixtures_path("test.xml") }

      it "parses xml file into Lutaml::Uml::Node::Document object" do
        expect(parse).to be_instance_of(Person)
      end

      it "expect to read the xml file" do
        input_xml = File.read(xml_file_path)

        expect(parse.to_xml(pretty: true)).to eq(input_xml)
      end
    end
  end
end
