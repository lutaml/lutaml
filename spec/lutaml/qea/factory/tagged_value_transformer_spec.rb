# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_tagged_value"
require_relative "../../../../lib/lutaml/qea/factory/tagged_value_transformer"

RSpec.describe Lutaml::Qea::Factory::TaggedValueTransformer do
  let(:database) { instance_double(Lutaml::Qea::Database) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    context "with valid EA tagged value" do
      let(:ea_tag) do
        Lutaml::Qea::Models::EaTaggedValue.new(
          property_id: "{GUID-1}",
          element_id: "{ELEMENT-GUID}",
          base_class: "ASSOCIATION_SOURCE",
          tag_value: "sequenceNumber|15$ea_notes=Unique integer value",
          notes: nil,
        )
      end

      it "transforms to UML TaggedValue" do
        result = transformer.transform(ea_tag)

        expect(result).to be_a(Lutaml::Uml::TaggedValue)
        expect(result.name).to eq("sequenceNumber")
        expect(result.value).to eq("15")
        expect(result.notes).to eq("Unique integer value")
      end
    end

    context "with tag value without pipe separator" do
      let(:ea_tag) do
        Lutaml::Qea::Models::EaTaggedValue.new(
          property_id: "{GUID-2}",
          element_id: "{ELEMENT-GUID}",
          base_class: "ASSOCIATION_SOURCE",
          tag_value: "isMetadata$ea_notes=Boolean flag",
          notes: nil,
        )
      end

      it "transforms with empty value" do
        result = transformer.transform(ea_tag)

        expect(result).to be_a(Lutaml::Uml::TaggedValue)
        expect(result.name).to eq("isMetadata")
        expect(result.value).to eq("")
        expect(result.notes).to eq("Boolean flag")
      end
    end

    context "with nil EA tag" do
      it "returns nil" do
        result = transformer.transform(nil)
        expect(result).to be_nil
      end
    end

    context "with EA tag without tag name" do
      let(:ea_tag) do
        Lutaml::Qea::Models::EaTaggedValue.new(
          property_id: "{GUID-3}",
          element_id: "{ELEMENT-GUID}",
          base_class: "ASSOCIATION_SOURCE",
          tag_value: nil,
          notes: "Some notes",
        )
      end

      it "returns nil" do
        result = transformer.transform(ea_tag)
        expect(result).to be_nil
      end
    end
  end

  describe "#transform_collection" do
    let(:ea_tags) do
      [
        Lutaml::Qea::Models::EaTaggedValue.new(
          property_id: "{GUID-1}",
          element_id: "{ELEMENT-GUID}",
          tag_value: "tag1|value1$ea_notes=Note1",
        ),
        Lutaml::Qea::Models::EaTaggedValue.new(
          property_id: "{GUID-2}",
          element_id: "{ELEMENT-GUID}",
          tag_value: "tag2|value2",
        ),
      ]
    end

    it "transforms collection of tagged values" do
      results = transformer.transform_collection(ea_tags)

      expect(results).to be_an(Array)
      expect(results.size).to eq(2)
      expect(results[0].name).to eq("tag1")
      expect(results[0].value).to eq("value1")
      expect(results[1].name).to eq("tag2")
      expect(results[1].value).to eq("value2")
    end
  end
end