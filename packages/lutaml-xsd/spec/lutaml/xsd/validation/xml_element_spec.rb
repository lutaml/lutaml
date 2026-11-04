# frozen_string_literal: true

require "spec_helper"
require "moxml"
require "lutaml/xsd/validation/xml_element"
require "lutaml/xsd/validation/xml_navigator"

RSpec.describe Lutaml::Xsd::Validation::XmlElement do
  let(:navigator) do
    Lutaml::Xsd::Validation::XmlNavigator.new(xml_content)
  end
  let(:xml_element) { navigator.root_element }

  context "with a namespaced document" do
    let(:xml_content) do
      <<~XML
        <person xmlns="http://example.com/test" id="1">
          <name>John</name>
        </person>
      XML
    end

    it "returns the element name" do
      expect(xml_element.name).to eq("person")
    end

    it "returns the namespace URI" do
      expect(xml_element.namespace_uri).to eq("http://example.com/test")
    end

    it "returns the Clark notation qualified name" do
      expect(xml_element.qualified_name)
        .to eq("{http://example.com/test}person")
    end

    it "returns the text content" do
      child = xml_element.children.first

      expect(child.text_content).to eq("John")
    end
  end

  context "with a prefixed document" do
    let(:xml_content) do
      <<~XML
        <t:person xmlns:t="http://example.com/test"/>
      XML
    end

    it "returns the namespace prefix" do
      expect(xml_element.prefix).to eq("t")
    end

    it "returns the namespace URI" do
      expect(xml_element.namespace_uri).to eq("http://example.com/test")
    end
  end

  context "without a namespace" do
    let(:xml_content) { "<person/>" }

    it "returns nil namespace URI" do
      expect(xml_element.namespace_uri).to be_nil
    end

    it "returns the bare qualified name" do
      expect(xml_element.qualified_name).to eq("person")
    end
  end
end
