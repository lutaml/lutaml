# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/models/ea_attribute_tag"
require_relative "../../../lib/lutaml/qea/factory/attribute_tag_transformer"
require_relative "../../../lib/lutaml/qea/services/database_loader"

RSpec.describe "Attribute Tags Support" do
  let(:qea_file) { "examples/qea/20251010_current_plateau_v5.1.qea" }

  describe Lutaml::Qea::Models::EaAttributeTag do
    describe ".from_db_row" do
      it "creates attribute tag from database row", :aggregate_failures do
        row = {
          "PropertyID" => 1,
          "ElementID" => 367,
          "Property" => "isMetadata",
          "VALUE" => "false",
          "NOTES" => nil,
          "ea_guid" => "{CB7388F0-4FF7-4c90-9849-996F41297C17}",
        }

        tag = described_class.from_db_row(row)

        expect(tag.property_id).to eq(1)
        expect(tag.element_id).to eq(367)
        expect(tag.property).to eq("isMetadata")
        expect(tag.value).to eq("false")
        expect(tag.ea_guid).to eq("{CB7388F0-4FF7-4c90-9849-996F41297C17}")
      end

      it "handles nil row" do
        tag = described_class.from_db_row(nil)
        expect(tag).to be_nil
      end
    end

    describe "#name" do
      it "returns the property name" do
        tag = described_class.new(property: "isMetadata")
        expect(tag.name).to eq("isMetadata")
      end
    end

    describe "#property_value" do
      it "returns the property value" do
        tag = described_class.new(value: "false")
        expect(tag.property_value).to eq("false")
      end
    end

    describe "#boolean_value" do
      it "parses 'true' as true" do
        tag = described_class.new(value: "true")
        expect(tag.boolean_value).to be true
      end

      it "parses 'false' as false" do
        tag = described_class.new(value: "false")
        expect(tag.boolean_value).to be false
      end

      it "returns nil for non-boolean values" do
        tag = described_class.new(value: "inline")
        expect(tag.boolean_value).to be_nil
      end
    end

    describe "#integer_value" do
      it "parses integer strings" do
        tag = described_class.new(value: "42")
        expect(tag.integer_value).to eq(42)
      end

      it "parses zero" do
        tag = described_class.new(value: "0")
        expect(tag.integer_value).to eq(0)
      end

      it "returns nil for non-integer values" do
        tag = described_class.new(value: "inline")
        expect(tag.integer_value).to be_nil
      end
    end
  end

  describe Lutaml::Qea::Factory::AttributeTagTransformer do
    let(:database) { instance_double(Lutaml::Qea::Database) }
    let(:transformer) { described_class.new(database) }

    describe "#transform" do
      it "transforms EA attribute tag to UML TaggedValue",
         :aggregate_failures do
        ea_tag = Lutaml::Qea::Models::EaAttributeTag.new(
          property_id: 1,
          element_id: 367,
          property: "isMetadata",
          value: "false",
        )

        uml_tag = transformer.transform(ea_tag)

        expect(uml_tag).to be_a(Lutaml::Uml::TaggedValue)
        expect(uml_tag.name).to eq("isMetadata")
        expect(uml_tag.value).to eq("false")
      end

      it "returns nil for nil input" do
        uml_tag = transformer.transform(nil)
        expect(uml_tag).to be_nil
      end

      it "returns nil for tag without property name" do
        ea_tag = Lutaml::Qea::Models::EaAttributeTag.new(
          property_id: 1,
          element_id: 367,
          property: nil,
          value: "false",
        )

        uml_tag = transformer.transform(ea_tag)
        expect(uml_tag).to be_nil
      end
    end
  end

  describe "Attribute Tags Integration" do
    let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_file) }
    let(:database) { loader.load }

    it "loads attribute tags from database", :aggregate_failures do
      expect(database.attribute_tags).not_to be_empty
      expect(database.attribute_tags.size).to eq(129)
    end

    it "loads attribute tags with correct structure", :aggregate_failures do
      tag = database.attribute_tags.first

      expect(tag).to be_a(Lutaml::Qea::Models::EaAttributeTag)
      expect(tag.property_id).not_to be_nil
      expect(tag.element_id).not_to be_nil
      expect(tag.property).not_to be_nil
    end

    it "includes expected property types", :aggregate_failures do
      property_names = database.attribute_tags.map(&:property).uniq

      expect(property_names).to include("isMetadata")
      expect(property_names).to include("sequenceNumber")
      expect(property_names).to include("inlineOrByReference")
    end

    it "attaches attribute tags to UML attributes as tagged values" do
      # Find an attribute that has tags
      aggregate_failures do
        attr_with_tags = database.attributes.find do |attr|
          database.attribute_tags.any? { |t| t.element_id == attr.id }
        end

        skip "No attributes with tags found" unless attr_with_tags

        # Transform to UML
        attr_transformer = Lutaml::Qea::Factory::AttributeTransformer.new(database)
        uml_attr = attr_transformer.transform(attr_with_tags)

        # Check that tagged values include attribute tags
        expect(uml_attr.tagged_values).not_to be_empty

        tag_names = database.attribute_tags
          .select { |t| t.element_id == attr_with_tags.id }
          .map(&:property)

        uml_tag_names = uml_attr.tagged_values.map(&:name)

        tag_names.each do |tag_name|
          expect(uml_tag_names).to include(tag_name)
        end
      end
    end
  end

  describe "Database Statistics" do
    let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_file) }
    let(:database) { loader.load }

    it "includes attribute_tags in database stats", :aggregate_failures do
      stats = database.stats

      expect(stats).to have_key("attribute_tags")
      expect(stats["attribute_tags"]).to eq(129)
    end
  end
end
