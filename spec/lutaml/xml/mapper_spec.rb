require "spec_helper"
require "shale"
require "lutaml/xml/mapper"

class TextWithTags < Lutaml::Xml::Mapper
  attribute :content, Shale::Type::String
  attribute :bold, Shale::Type::String, collection: true
  attribute :italic, Shale::Type::String, collection: true

  xml do
    root "text"

    map_content to: :content
    map_element :b, to: :bold
    map_element :i, to: :italic
  end
end

RSpec.describe Lutaml::Xml::Mapper do
  describe ".of_xml" do
    subject(:of_xml) { TextWithTags.of_xml(element) }

    context "correctly parses xml document" do
      let(:xml) do
        <<~XML
          <text>
            Here is some text with <b>bold</b> and some <i>italics</i>.
          </text>
        XML
      end
      let(:element) { Shale.xml_adapter.load(xml) }

      it "parses xml file into TextWithTags object" do
        expect(of_xml).to be_instance_of(TextWithTags)
      end

      it "expect to read and convert to_xml correctly" do
        expect(of_xml.to_xml(pretty: true)).to eq(xml)
      end
    end
  end
end
