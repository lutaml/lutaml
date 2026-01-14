# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/models/ea_object_property"
require_relative "../../../lib/lutaml/qea/factory/object_property_transformer"
require_relative "../../../lib/lutaml/qea/services/database_loader"

RSpec.describe "Object Properties Support" do
  let(:qea_file) { "examples/qea/20251010_current_plateau_v5.1.qea" }

  describe Lutaml::Qea::Models::EaObjectProperty do
    describe ".from_db_row" do
      it "creates object property from database row" do
        row = {
          "PropertyID" => 1,
          "Object_ID" => 684,
          "Property" => "isCollection",
          "Value" => "false",
          "Notes" => "Values: true,false\nDefault: false\nDescription: Identifies the class as a collection",
          "ea_guid" => "{26B33348-88EC-9d88-8810-4D66A3769CC7}"
        }

        property = described_class.from_db_row(row)

        expect(property.property_id).to eq(1)
        expect(property.ea_object_id).to eq(684)
        expect(property.property).to eq("isCollection")
        expect(property.value).to eq("false")
        expect(property.notes).to include("Identifies the class")
        expect(property.ea_guid).to eq("{26B33348-88EC-9d88-8810-4D66A3769CC7}")
      end

      it "handles nil row" do
        property = described_class.from_db_row(nil)
        expect(property).to be_nil
      end
    end

    describe "#name" do
      it "returns the property name" do
        property = described_class.new(property: "isCollection")
        expect(property.name).to eq("isCollection")
      end
    end

    describe "#property_value" do
      it "returns the property value" do
        property = described_class.new(value: "false")
        expect(property.property_value).to eq("false")
      end
    end

    describe "#boolean_value" do
      it "parses 'true' as true" do
        property = described_class.new(value: "true")
        expect(property.boolean_value).to be true
      end

      it "parses 'false' as false" do
        property = described_class.new(value: "false")
        expect(property.boolean_value).to be false
      end

      it "parses '1' as true" do
        property = described_class.new(value: "1")
        expect(property.boolean_value).to be true
      end

      it "parses '0' as false" do
        property = described_class.new(value: "0")
        expect(property.boolean_value).to be false
      end

      it "returns nil for non-boolean values" do
        property = described_class.new(value: "someValue")
        expect(property.boolean_value).to be_nil
      end
    end

    describe "#boolean?" do
      it "returns true for boolean values" do
        property = described_class.new(value: "true")
        expect(property).to be_boolean
      end

      it "returns false for non-boolean values" do
        property = described_class.new(value: "someValue")
        expect(property).not_to be_boolean
      end
    end
  end

  describe Lutaml::Qea::Factory::ObjectPropertyTransformer do
    let(:database) { instance_double(Lutaml::Qea::Database) }
    let(:transformer) { described_class.new(database) }

    describe "#transform" do
      it "transforms EA object property to UML TaggedValue" do
        ea_prop = Lutaml::Qea::Models::EaObjectProperty.new(
          property_id: 1,
          object_id: 684,
          property: "isCollection",
          value: "false",
          notes: "Description: Identifies the class as a collection"
        )

        uml_tag = transformer.transform(ea_prop)

        expect(uml_tag).to be_a(Lutaml::Uml::TaggedValue)
        expect(uml_tag.name).to eq("isCollection")
        expect(uml_tag.value).to eq("false")
        expect(uml_tag.notes).to include("Identifies the class")
      end

      it "returns nil for nil input" do
        uml_tag = transformer.transform(nil)
        expect(uml_tag).to be_nil
      end

      it "returns nil for property without name" do
        ea_prop = Lutaml::Qea::Models::EaObjectProperty.new(
          property_id: 1,
          object_id: 684,
          property: nil,
          value: "false"
        )

        uml_tag = transformer.transform(ea_prop)
        expect(uml_tag).to be_nil
      end
    end
  end

  describe "Object Properties Integration" do
    let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_file) }
    let(:database) { loader.load }

    it "loads object properties from database" do
      expect(database.object_properties).not_to be_empty
      expect(database.object_properties.size).to eq(1537)
    end

    it "loads object properties with correct structure" do
      property = database.object_properties.first

      expect(property).to be_a(Lutaml::Qea::Models::EaObjectProperty)
      expect(property.property_id).not_to be_nil
      expect(property.object_id).not_to be_nil
      expect(property.property).not_to be_nil
    end

    it "includes common property types" do
      property_names = database.object_properties.map(&:property).uniq

      expect(property_names).to include("isCollection")
      expect(property_names).to include("noPropertyType")
      expect(property_names).to include("byValuePropertyType")
    end

    it "attaches object properties to UML classes as tagged values" do
      # Find an object that has properties
      object_with_props = database.objects.all.find do |obj|
        database.object_properties.any? { |p| p.object_id == obj.object_id }
      end

      skip "No objects with properties found" unless object_with_props

      # Transform to UML using class transformer directly
      class_transformer = Lutaml::Qea::Factory::ClassTransformer.new(database)
      uml_class = class_transformer.transform(object_with_props)

      # Check that tagged values include object properties
      expect(uml_class.tagged_values).not_to be_empty

      property_tag_names = database.object_properties
        .select { |p| p.object_id == object_with_props.object_id }
        .map(&:property)

      uml_tag_names = uml_class.tagged_values.map(&:name)

      property_tag_names.each do |prop_name|
        expect(uml_tag_names).to include(prop_name)
      end
    end
  end

  describe "Database Statistics" do
    let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_file) }
    let(:database) { loader.load }

    it "includes object_properties in database stats" do
      stats = database.stats

      expect(stats).to have_key("object_properties")
      expect(stats["object_properties"]).to eq(1537)
    end
  end
end