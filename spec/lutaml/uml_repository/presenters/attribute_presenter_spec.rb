# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "presenters/attribute_presenter"
require_relative "../../../../lib/lutaml/uml/top_element_attribute"

RSpec.describe Lutaml::UmlRepository::Presenters::AttributePresenter do
  let(:attribute) do
    Lutaml::Uml::TopElementAttribute.new.tap do |attr|
      attr.name = "buildingHeight"
      attr.type = "Double"
    end
  end

  let(:context) do
    {
      class_name: "Building",
      class_qname: "CityGML::Building::Building",
      qualified_name: "CityGML::Building::Building::buildingHeight",
    }
  end

  let(:repository) { nil }

  describe "#initialize" do
    it "accepts an element, repository, and context", :aggregate_failures do
      presenter = described_class.new(attribute, repository, context)
      expect(presenter.element).to eq(attribute)
      expect(presenter.context).to eq(context)
    end

    it "uses empty hash for context if not provided" do
      presenter = described_class.new(attribute, repository)
      expect(presenter.context).to eq({})
    end
  end

  describe "#to_text" do
    it "formats attribute details as text", :aggregate_failures do
      presenter = described_class.new(attribute, repository, context)
      result = presenter.to_text

      expect(result).to include("Attribute: CityGML::Building::Building::buildingHeight")
      expect(result).to include("Name:          buildingHeight")
      expect(result).to include("Class:         Building")
      expect(result).to include("Type:          Double")
      expect(result).to include("Cardinality:")
    end

    it "handles missing context gracefully" do
      presenter = described_class.new(attribute, repository)
      result = presenter.to_text

      expect(result).to include("Class:         Unknown")
    end
  end

  describe "#to_table_row" do
    it "returns a hash suitable for table display", :aggregate_failures do
      presenter = described_class.new(attribute, repository, context)
      result = presenter.to_table_row

      expect(result).to be_a(Hash)
      expect(result[:type]).to eq("Attribute")
      expect(result[:name]).to eq("buildingHeight")
      expect(result[:details]).to eq("Building::buildingHeight : Double")
    end

    it "handles unnamed attributes" do
      attribute.name = nil
      presenter = described_class.new(attribute, repository, context)
      result = presenter.to_table_row

      expect(result[:name]).to eq("(unnamed)")
    end
  end

  describe "#to_hash" do
    it "returns a hash with attribute data", :aggregate_failures do
      presenter = described_class.new(attribute, repository, context)
      result = presenter.to_hash

      expect(result).to be_a(Hash)
      expect(result[:type]).to eq("Attribute")
      expect(result[:name]).to eq("buildingHeight")
      expect(result[:class_name]).to eq("Building")
      expect(result[:attr_type]).to eq("Double")
      expect(result[:cardinality]).to be_a(String)
    end

    it "includes optional fields when present" do
      attribute.instance_variable_set(:@visibility, "public")
      presenter = described_class.new(attribute, repository, context)
      result = presenter.to_hash

      expect(result).to have_key(:visibility)
    end
  end

  describe "PresenterFactory registration" do
    it "registers AttributePresenter for TopElementAttribute" do
      factory = Lutaml::UmlRepository::Presenters::PresenterFactory
      presenter = factory.create(attribute, repository, context)
      expect(presenter).to be_a(described_class)
    end
  end
end
