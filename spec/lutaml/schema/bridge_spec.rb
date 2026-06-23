# frozen_string_literal: true

require "spec_helper"
require "json"
require_relative "../../../lib/lutaml/schema/bridge"

RSpec.describe Lutaml::Schema::Bridge do
  def attribute(name, type, tags = {})
    Lutaml::Uml::TopElementAttribute.new(
      name: name, type: type,
      tagged_values: tags.map do |key, value|
        Lutaml::Uml::TaggedValue.new(name: key.to_s, value: value.to_s)
      end
    )
  end

  let(:document) do
    address = Lutaml::Uml::Class.new(
      name: "Address",
      attributes: [
        attribute("id", "String", xmlAttribute: "true"),
        attribute("street", "String", sequenceNumber: 2),
        attribute("city", "String", sequenceNumber: 1),
        attribute("postcode", "Integer"),
      ],
    )
    inner = Lutaml::Uml::Package.new(
      name: "Inner",
      classes: [Lutaml::Uml::Class.new(name: "Nested", attributes: [])],
    )
    Lutaml::Uml::Document.new(name: "M", classes: [address], packages: [inner])
  end

  let(:bridge) { described_class.new(document) }

  describe "#class_names" do
    it "collects classes across the whole package tree" do
      expect(bridge.class_names).to contain_exactly("Address", "Nested")
    end
  end

  describe "#to_xsd" do
    let(:xsd) { bridge.to_xsd("Address") }

    it "maps xmlAttribute to <attribute> and orders elements by sequenceNumber",
       :aggregate_failures do
      expect(xsd).to include('<attribute name="id"')
      elements = xsd.scan(/<element name="(\w+)"/).flatten
      # root Address, then city(seq 1), street(seq 2), postcode(unnumbered last)
      expect(elements).to eq(%w[Address city street postcode])
      expect(xsd).to include('<attribute name="id" type="xs:string"')
    end
  end

  describe "#to_json_schema" do
    it "produces a draft-2020-12 schema carrying every property",
       :aggregate_failures do
      schema = JSON.parse(bridge.to_json_schema("Address"))
      expect(schema["$schema"]).to include("2020-12")
      props = schema.dig("$defs", "Address", "properties")
      expect(props.keys).to contain_exactly("id", "street", "city", "postcode")
    end
  end

  describe "an unknown class" do
    it "raises listing the available class names" do
      expect { bridge.to_xsd("Nope") }
        .to raise_error(ArgumentError, /Available: Address, Nested/)
    end
  end

  describe "name handling" do
    def document_with(*attributes)
      Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(name: "X", attributes: attributes)],
      )
    end

    it "uses a hyphenated UML name verbatim as the element name" do
      doc = document_with(attribute("postal-code", "String", sequenceNumber: 1))
      expect(described_class.new(doc).to_xsd("X"))
        .to include('<element name="postal-code"')
    end

    it "rejects attribute names that are not valid XML names" do
      doc = document_with(attribute("type/text", "String"))
      expect { described_class.new(doc).to_xsd("X") }
        .to raise_error(ArgumentError, %r{not valid XML names: type/text})
    end

    it "rejects duplicate attribute names" do
      doc = document_with(attribute("a", "String"), attribute("a", "Integer"))
      expect { described_class.new(doc).to_xsd("X") }
        .to raise_error(ArgumentError, /duplicate attribute name/)
    end

    it "refuses to disambiguate duplicate simple class names" do
      pkg = Lutaml::Uml::Package.new(
        name: "P",
        classes: [Lutaml::Uml::Class.new(name: "Dup", attributes: [])],
      )
      doc = Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(name: "Dup", attributes: [])],
        packages: [pkg],
      )
      expect { described_class.new(doc).to_xsd("Dup") }
        .to raise_error(ArgumentError, /cannot disambiguate/)
    end
  end
end
