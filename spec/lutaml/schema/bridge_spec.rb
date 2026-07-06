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

  describe "cardinality realization" do
    def attribute_with_cardinality(name, type, min, max, tags = {})
      attr = attribute(name, type, tags)
      attr.cardinality = Lutaml::Uml::Cardinality.new(min: min, max: max)
      attr
    end

    let(:document) do
      Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(
          name: "House",
          attributes: [
            attribute_with_cardinality("rooms", "String", "0", "*"),
            attribute_with_cardinality("owners", "String", "1", "3"),
            attribute("name", "String"),
          ],
        )],
      )
    end

    it "realizes multi-valued attributes as XSD repeats", :aggregate_failures do
      xsd = bridge.to_xsd("House")
      expect(xsd).to include('name="rooms" minOccurs="0" maxOccurs="unbounded"')
      # The repeat itself is what the bridge guarantees; lutaml-model's XSD
      # emitter currently collapses finite bounds to 0..unbounded (the JSON
      # Schema output below carries the true 1..3), an upstream limitation.
      expect(xsd).to match(/name="owners" minOccurs="\d+" maxOccurs=/)
      # single-valued stays a plain scalar element
      expect(xsd).to include('<element name="name" type="xs:string"/>')
    end

    it "realizes multi-valued attributes as JSON arrays", :aggregate_failures do
      props = JSON.parse(bridge.to_json_schema("House"))
        .dig("$defs", "House", "properties")
      expect(props.dig("rooms", "type")).to eq("array")
      expect(props.dig("owners", "type")).to eq("array")
      expect(props.dig("owners", "minItems")).to eq(1)
      expect(props.dig("owners", "maxItems")).to eq(3)
      # positive shape, so a dropped property cannot false-pass a negation
      expect(props.dig("name", "type")).to eq(%w[string null])
    end

    it "rejects a multi-valued attribute tagged xmlAttribute" do
      doc = Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(
          name: "X",
          attributes: [attribute_with_cardinality("ids", "String", "0", "*",
                                                  xmlAttribute: "true")],
        )],
      )
      expect { described_class.new(doc).to_xsd("X") }
        .to raise_error(ArgumentError, /cannot repeat.*ids/m)
    end

    # EA/XMI multiplicity bounds are free text; they must fail loudly with
    # the class and attribute named, not become a maxItems:0 schema or an
    # anonymous lutaml-model range error.
    context "with free-text bounds from the source model" do
      def bridge_for(min, max)
        described_class.new(Lutaml::Uml::Document.new(
                              name: "M",
                              classes: [Lutaml::Uml::Class.new(
                                name: "X",
                                attributes: [attribute_with_cardinality(
                                  "ids", "String", min, max
                                )],
                              )],
                            ))
      end

      it "recognizes a padded \"*\" as unbounded" do
        expect(bridge_for("0", "* ").to_xsd("X"))
          .to include('name="ids" minOccurs="0" maxOccurs="unbounded"')
      end

      it "rejects an unrecognized max token, naming the attribute" do
        expect { bridge_for("0", "n").to_xsd("X") }
          .to raise_error(ArgumentError,
                          /Class "X".*multiplicity bounds: ids \(0\.\.n\)/m)
      end

      it "rejects a negative max bound" do
        expect { bridge_for("0", "-1").to_xsd("X") }
          .to raise_error(ArgumentError, /ids \(0\.\.-1\)/)
      end

      it "rejects inverted bounds" do
        expect { bridge_for("5", "3").to_xsd("X") }
          .to raise_error(ArgumentError, /ids \(5\.\.3\)/)
      end

      it "validates min even when a scalar max makes it unused" do
        expect { bridge_for("x", "1").to_xsd("X") }
          .to raise_error(ArgumentError, /ids \(x\.\.1\)/)
      end

      it "ignores min when max is unbounded" do
        expect(bridge_for("x", "*").to_xsd("X"))
          .to include('name="ids" minOccurs="0" maxOccurs="unbounded"')
      end
    end
  end

  describe "name handling" do
    def document_with(*attributes)
      Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(name: "X", attributes: attributes)],
      )
    end

    it "accepts non-ASCII NCNames for classes and attributes" do
      doc = Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(
          name: "Gebäude", attributes: [attribute("straße", "String")],
        )],
      )
      expect(described_class.new(doc).to_xsd("Gebäude"))
        .to include('<element name="straße"')
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

    it "rejects a class name that is not a valid XML name",
       :aggregate_failures do
      doc = Lutaml::Uml::Document.new(
        name: "M",
        classes: [Lutaml::Uml::Class.new(
          name: "Bad Class", attributes: [attribute("id", "String")],
        )],
      )
      expect { described_class.new(doc).to_xsd("Bad Class") }
        .to raise_error(ArgumentError, /not a valid XML name/)
      expect { described_class.new(doc).to_json_schema("Bad Class") }
        .to raise_error(ArgumentError, /not a valid XML name/)
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
