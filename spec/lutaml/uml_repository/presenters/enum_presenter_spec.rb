# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/presenters/enum_presenter"
require_relative "../../../../lib/lutaml/uml/enum"

RSpec.describe Lutaml::UmlRepository::Presenters::EnumPresenter do
  let(:values) do
    [
      Lutaml::Uml::Value.new(name: "Red"),
      Lutaml::Uml::Value.new(name: "Green"),
      Lutaml::Uml::Value.new(name: "Blue"),
    ]
  end

  let(:enum_element) do
    Lutaml::Uml::Enum.new(
      name: "Color",
      xmi_id: "ENUM_001",
      visibility: "public",
      values: values,
    ).tap { |e| e.stereotype << "entity" }
  end

  let(:presenter) { described_class.new(enum_element) }

  describe "#to_text" do
    it "generates formatted text output", :aggregate_failures do
      text = presenter.to_text
      expect(text).to include("Enumeration: Color")
      expect(text).to include("=" * 50)
      expect(text).to include("Name:          Color")
      expect(text).to include("XMI ID:        ENUM_001")
      expect(text).to include("Visibility:    public")
    end

    it "includes literal values" do
      text = presenter.to_text
      expect(text).to include("Literal Values (3):")
      expect(text).to include("Red")
      expect(text).to include("Green")
      expect(text).to include("Blue")
    end

    it "handles enum without xmi_id" do
      enum_element.xmi_id = nil
      expect(presenter.to_text).not_to include("XMI ID:")
    end

    it "handles enum without values" do
      enum_element.values = []
      expect(presenter.to_text).to include("Literal Values: (none)")
    end
  end

  describe "#to_table_row" do
    it "generates table row hash", :aggregate_failures do
      row = presenter.to_table_row
      expect(row[:type]).to eq("Enumeration")
      expect(row[:name]).to eq("Color")
      expect(row[:details]).to eq("3 literal value(s)")
    end

    it "handles unnamed enum" do
      enum_element.name = nil
      expect(presenter.to_table_row[:name]).to eq("(unnamed)")
    end

    it "handles enum without values" do
      enum_element.values = []
      expect(presenter.to_table_row[:details]).to eq("0 literal value(s)")
    end
  end

  describe "#to_hash" do
    it "generates structured hash", :aggregate_failures do
      hash = presenter.to_hash
      expect(hash[:type]).to eq("Enumeration")
      expect(hash[:name]).to eq("Color")
      expect(hash[:xmi_id]).to eq("ENUM_001")
      expect(hash[:visibility]).to eq("public")
      expect(hash[:value_count]).to eq(3)
      expect(hash[:values]).to eq(%w[Red Green Blue])
    end

    it "excludes xmi_id when nil" do
      enum_element.xmi_id = nil
      expect(presenter.to_hash).not_to have_key(:xmi_id)
    end

    it "excludes stereotype when empty" do
      enum_element.stereotype.clear
      expect(presenter.to_hash).not_to have_key(:stereotype)
    end

    it "excludes values when empty" do
      enum_element.values = []
      expect(presenter.to_hash).not_to have_key(:values)
    end
  end

  describe "factory registration" do
    it "registers with PresenterFactory" do
      factory = Lutaml::UmlRepository::Presenters::PresenterFactory
      expect(factory.presenters[Lutaml::Uml::Enum]).to eq(described_class)
    end
  end

  describe "inheritance" do
    it "inherits from ElementPresenter" do
      expect(described_class.superclass)
        .to eq(Lutaml::UmlRepository::Presenters::ElementPresenter)
    end

    it "exposes element attribute" do
      expect(presenter.element).to eq(enum_element)
    end
  end
end
