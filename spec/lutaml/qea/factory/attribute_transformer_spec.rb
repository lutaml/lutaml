# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/attribute_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_attribute"

RSpec.describe Lutaml::Qea::Factory::AttributeTransformer do
  let(:database) { double("Database") }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "transforms EA attribute to UML attribute", :aggregate_failures do
      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        name: "firstName",
        type: "String",
        scope: "Public",
        ea_guid: "{ATTR-GUID}",
        isstatic: 0,
        derived: "0",
        notes: "Person's first name",
      )

      result = transformer.transform(ea_attr)

      expect(result).to be_a(Lutaml::Uml::TopElementAttribute)
      expect(result.name).to eq("firstName")
      expect(result.type).to eq("String")
      expect(result.visibility).to eq("public")
      expect(result.xmi_id).to eq("EAID_ATTR_GUID")
      expect(result.static).to be_nil
      expect(result.is_derived).to be false
      expect(result.definition).to eq("Person's first name")
    end

    it "marks static attributes" do
      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        name: "count",
        type: "Integer",
        isstatic: 1,
      )

      result = transformer.transform(ea_attr)

      expect(result.static).to eq("true")
    end

    it "marks derived attributes" do
      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        name: "fullName",
        derived: "1",
      )

      result = transformer.transform(ea_attr)

      expect(result.is_derived).to be true
    end

    it "builds cardinality from bounds", :aggregate_failures do
      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        name: "tags",
        lowerbound: "0",
        upperbound: "*",
      )

      result = transformer.transform(ea_attr)

      expect(result.cardinality).to be_a(Lutaml::Uml::Cardinality)
      expect(result.cardinality.min).to eq("0")
      expect(result.cardinality.max).to eq("*")
    end

    it "handles nil cardinality bounds" do
      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        name: "simple",
        lowerbound: nil,
        upperbound: nil,
      )

      result = transformer.transform(ea_attr)

      expect(result.cardinality).to be_nil
    end

    it "maps visibility correctly" do
      ["Public", "Private", "Protected"].each do |visibility|
        ea_attr = Lutaml::Qea::Models::EaAttribute.new(
          name: "attr",
          scope: visibility,
        )

        result = transformer.transform(ea_attr)

        expect(result.visibility).to eq(visibility.downcase)
      end
    end

    it "skips empty notes" do
      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        name: "attr",
        notes: "",
      )

      result = transformer.transform(ea_attr)

      expect(result.definition).to be_nil
    end
  end
end
