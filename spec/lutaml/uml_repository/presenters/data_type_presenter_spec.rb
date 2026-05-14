# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/presenters/datatype_presenter"
require_relative "../../../../lib/lutaml/uml/data_type"

RSpec.describe Lutaml::UmlRepository::Presenters::DataTypePresenter do
  let(:attributes) do
    [
      Lutaml::Uml::TopElementAttribute.new(name: "id", type: "String"),
      Lutaml::Uml::TopElementAttribute.new(name: "count", type: "Integer"),
    ]
  end

  let(:operations) do
    [
      Lutaml::Uml::Operation.new(name: "validate"),
      Lutaml::Uml::Operation.new(name: "to_s"),
    ]
  end

  let(:datatype_element) do
    dt = Lutaml::Uml::DataType.new(
      name: "Address",
      xmi_id: "DT_001",
      type: "complexType",
      visibility: "public",
      is_abstract: false,
      attributes: attributes,
      operations: operations,
    )
    dt.stereotype << "valueObject"
    dt
  end

  let(:presenter) { described_class.new(datatype_element) }

  describe "#to_text" do
    it "generates formatted text output", :aggregate_failures do
      text = presenter.to_text
      expect(text).to include("DataType: Address")
      expect(text).to include("=" * 50)
      expect(text).to include("Name:          Address")
      expect(text).to include("XMI ID:        DT_001")
      expect(text).to include("Visibility:    public")
      expect(text).to include("Abstract:      false")
    end

    it "includes attributes with types", :aggregate_failures do
      text = presenter.to_text
      expect(text).to include("Attributes (2):")
      expect(text).to include("id : String")
      expect(text).to include("count : Integer")
    end

    it "includes operations", :aggregate_failures do
      text = presenter.to_text
      expect(text).to include("Operations (2):")
      expect(text).to include("validate()")
      expect(text).to include("to_s()")
    end

    it "handles datatype without xmi_id" do
      datatype_element.xmi_id = nil
      expect(presenter.to_text).not_to include("XMI ID:")
    end

    it "handles datatype without type" do
      datatype_element.type = nil
      expect(presenter.to_text).not_to match(/^Type:\s/)
    end

    it "handles datatype without stereotype" do
      datatype_element.stereotype.clear
      expect(presenter.to_text).not_to include("Stereotype:")
    end

    it "handles datatype without attributes" do
      datatype_element.attributes = []
      expect(presenter.to_text).not_to include("Attributes")
    end

    it "handles datatype without operations" do
      datatype_element.operations = []
      expect(presenter.to_text).not_to include("Operations")
    end
  end

  describe "#to_table_row" do
    it "generates table row hash", :aggregate_failures do
      row = presenter.to_table_row
      expect(row[:type]).to eq("DataType")
      expect(row[:name]).to eq("Address")
      expect(row[:details]).to eq("2 attribute(s)")
    end

    it "handles unnamed datatype" do
      datatype_element.name = nil
      expect(presenter.to_table_row[:name]).to eq("(unnamed)")
    end

    it "handles datatype without attributes" do
      datatype_element.attributes = []
      expect(presenter.to_table_row[:details]).to eq("0 attribute(s)")
    end
  end

  describe "#to_hash" do
    it "generates structured hash", :aggregate_failures do
      hash = presenter.to_hash
      expect(hash[:type]).to eq("DataType")
      expect(hash[:name]).to eq("Address")
      expect(hash[:xmi_id]).to eq("DT_001")
      expect(hash[:data_type]).to eq("complexType")
      expect(hash[:visibility]).to eq("public")
      expect(hash[:is_abstract]).to be(false)
    end

    it "includes attributes as array of hashes", :aggregate_failures do
      attrs = presenter.to_hash[:attributes]
      expect(attrs.size).to eq(2)
      expect(attrs[0]).to eq({ name: "id", type: "String" })
      expect(attrs[1]).to eq({ name: "count", type: "Integer" })
    end

    it "includes operations as array of names" do
      expect(presenter.to_hash[:operations]).to eq(%w[validate to_s])
    end

    it "excludes xmi_id when nil" do
      datatype_element.xmi_id = nil
      expect(presenter.to_hash).not_to have_key(:xmi_id)
    end

    it "excludes stereotype when empty" do
      datatype_element.stereotype.clear
      expect(presenter.to_hash).not_to have_key(:stereotype)
    end

    it "excludes attributes when empty" do
      datatype_element.attributes = []
      expect(presenter.to_hash).not_to have_key(:attributes)
    end

    it "excludes operations when empty" do
      datatype_element.operations = []
      expect(presenter.to_hash).not_to have_key(:operations)
    end
  end

  describe "factory registration" do
    it "registers with PresenterFactory" do
      factory = Lutaml::UmlRepository::Presenters::PresenterFactory
      expect(factory.presenters[Lutaml::Uml::DataType]).to eq(described_class)
    end
  end

  describe "inheritance" do
    it "inherits from ElementPresenter" do
      expect(described_class.superclass)
        .to eq(Lutaml::UmlRepository::Presenters::ElementPresenter)
    end

    it "exposes element attribute" do
      expect(presenter.element).to eq(datatype_element)
    end
  end
end
