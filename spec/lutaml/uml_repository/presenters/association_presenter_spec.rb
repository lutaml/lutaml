# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "presenters/association_presenter"
require_relative "../../../../lib/lutaml/uml/association"

RSpec.describe Lutaml::UmlRepository::Presenters::AssociationPresenter do
  let(:association) do
    Lutaml::Uml::Association.new.tap do |assoc|
      assoc.name = "buildingAssociation"
      assoc.owner_end = "Building"
      assoc.member_end = ["CityObject"]
    end
  end

  let(:context) do
    {
      source: "Building",
      target: "CityObject",
    }
  end

  let(:repository) { nil }

  describe "#initialize" do
    it "accepts an element, repository, and context" do
      presenter = described_class.new(association, repository, context)
      expect(presenter.element).to eq(association)
      expect(presenter.context).to eq(context)
    end

    it "uses empty hash for context if not provided" do
      presenter = described_class.new(association, repository)
      expect(presenter.context).to eq({})
    end
  end

  describe "#to_text" do
    it "formats association details as text" do
      presenter = described_class.new(association, repository, context)
      result = presenter.to_text

      expect(result).to include("Association: buildingAssociation")
      expect(result).to include("Name:          buildingAssociation")
      expect(result).to include("Source:        Building")
      expect(result).to include("Target:        CityObject")
    end

    it "handles unnamed associations" do
      association.name = nil
      presenter = described_class.new(association, repository, context)
      result = presenter.to_text

      expect(result).to include("Association: (unnamed)")
      expect(result).to include("Name:          (unnamed)")
    end
  end

  describe "#to_table_row" do
    it "returns a hash suitable for table display" do
      presenter = described_class.new(association, repository, context)
      result = presenter.to_table_row

      expect(result).to be_a(Hash)
      expect(result[:type]).to eq("Association")
      expect(result[:name]).to eq("buildingAssociation")
      expect(result[:details]).to eq("Building → CityObject")
    end

    it "handles unnamed associations" do
      association.name = nil
      presenter = described_class.new(association, repository, context)
      result = presenter.to_table_row

      expect(result[:name]).to eq("(unnamed)")
    end
  end

  describe "#to_hash" do
    it "returns a hash with association data" do
      presenter = described_class.new(association, repository, context)
      result = presenter.to_hash

      expect(result).to be_a(Hash)
      expect(result[:type]).to eq("Association")
      expect(result[:name]).to eq("buildingAssociation")
      expect(result[:source]).to eq("Building")
      expect(result[:target]).to eq("CityObject")
    end

    it "includes xmi_id when present" do
      association.instance_variable_set(:@xmi_id, "EAID_12345")
      presenter = described_class.new(association, repository, context)
      result = presenter.to_hash

      expect(result).to have_key(:xmi_id)
      expect(result[:xmi_id]).to eq("EAID_12345")
    end
  end

  describe "PresenterFactory registration" do
    it "registers AssociationPresenter for Association" do
      factory = Lutaml::UmlRepository::Presenters::PresenterFactory
      presenter = factory.create(association, repository, context)
      expect(presenter).to be_a(described_class)
    end
  end

  describe "#source_display" do
    it "uses context source when available" do
      presenter = described_class.new(association, repository, context)
      result = presenter.to_hash
      expect(result[:source]).to eq("Building")
    end

    it "falls back to owner_end when context is missing" do
      presenter = described_class.new(association, repository)
      result = presenter.to_hash
      expect(result[:source]).to eq("Building")
    end

    it "returns Unknown when both are missing" do
      association.owner_end = nil
      presenter = described_class.new(association, repository)
      result = presenter.to_hash
      expect(result[:source]).to eq("Unknown")
    end
  end

  describe "#target_display" do
    it "uses context target when available" do
      presenter = described_class.new(association, repository, context)
      result = presenter.to_hash
      expect(result[:target]).to eq("CityObject")
    end

    it "extracts from member_end when context is missing" do
      presenter = described_class.new(association, repository)
      result = presenter.to_hash
      expect(result[:target]).to eq("CityObject")
    end

    it "returns Unknown when both are missing" do
      association.member_end = nil
      presenter = described_class.new(association, repository)
      result = presenter.to_hash
      expect(result[:target]).to eq("Unknown")
    end
  end
end
