# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "presenters/class_presenter"
require_relative "../../../../lib/lutaml/uml/class"

RSpec.describe Lutaml::UmlRepository::Presenters::ClassPresenter do
  let(:mock_class) do
    instance_double(
      Lutaml::Uml::Class,
      name: "TestClass",
      xmi_id: "CLASS_001",
      stereotype: "entity",
      is_abstract: false,
    )
  end

  let(:mock_repository) { double("Repository") }
  let(:presenter) { described_class.new(mock_class, mock_repository) }

  describe "#to_text" do
    it "generates formatted text output" do
      text = presenter.to_text
      expect(text).to include("Class: TestClass")
      expect(text).to include("=" * 50)
      expect(text).to include("Name:        TestClass")
      expect(text).to include("XMI ID:      CLASS_001")
      expect(text).to include("Stereotype:  entity")
      expect(text).to include("Abstract:    false")
    end

    it "handles class with nil xmi_id" do
      allow(mock_class).to receive(:xmi_id).and_return(nil)
      text = presenter.to_text
      expect(text).not_to include("XMI ID:")
    end

    it "handles class with nil stereotype" do
      allow(mock_class).to receive(:stereotype).and_return(nil)
      text = presenter.to_text
      expect(text).not_to include("Stereotype:")
    end
  end

  describe "#to_table_row" do
    it "generates table row hash" do
      row = presenter.to_table_row
      expect(row).to be_a(Hash)
      expect(row[:type]).to eq("Class")
      expect(row[:name]).to eq("TestClass")
      expect(row[:details]).to eq("<<entity>>")
    end

    it "handles unnamed class" do
      allow(mock_class).to receive(:name).and_return(nil)
      row = presenter.to_table_row
      expect(row[:name]).to eq("(unnamed)")
    end

    it "handles class without stereotype" do
      allow(mock_class).to receive(:respond_to?)
        .with(:stereotype).and_return(false)
      row = presenter.to_table_row
      expect(row[:details]).to eq("")
    end

    it "handles class with nil stereotype" do
      allow(mock_class).to receive(:stereotype).and_return(nil)
      row = presenter.to_table_row
      expect(row[:details]).to eq("")
    end
  end

  describe "#to_hash" do
    it "generates structured hash" do
      hash = presenter.to_hash
      expect(hash).to be_a(Hash)
      expect(hash[:type]).to eq("Class")
      expect(hash[:name]).to eq("TestClass")
      expect(hash[:xmi_id]).to eq("CLASS_001")
      expect(hash[:stereotype]).to eq("entity")
      expect(hash[:is_abstract]).to eq(false)
    end

    it "excludes xmi_id if not available" do
      allow(mock_class).to receive(:xmi_id).and_return(nil)
      hash = presenter.to_hash
      expect(hash).not_to have_key(:xmi_id)
    end

    it "excludes stereotype if not available" do
      allow(mock_class).to receive(:stereotype).and_return(nil)
      hash = presenter.to_hash
      expect(hash).not_to have_key(:stereotype)
    end

    it "excludes is_abstract if not available" do
      allow(mock_class).to receive(:is_abstract).and_return(nil)
      hash = presenter.to_hash
      expect(hash).to have_key(:is_abstract)
      expect(hash[:is_abstract]).to eq(false)
    end

    it "includes all available fields" do
      hash = presenter.to_hash
      expect(hash.keys).to match_array(%i[type name xmi_id
                                          stereotype is_abstract])
    end
  end

  describe "factory registration" do
    it "registers with PresenterFactory" do
      factory = Lutaml::UmlRepository::Presenters::PresenterFactory
      expect(factory.presenters[Lutaml::Uml::Class])
        .to eq(described_class)
    end
  end

  describe "inheritance from ElementPresenter" do
    it "inherits from ElementPresenter" do
      expect(described_class.superclass)
        .to eq(Lutaml::UmlRepository::Presenters::ElementPresenter)
    end

    it "has access to element attribute" do
      expect(presenter.element).to eq(mock_class)
    end

    it "has access to repository attribute" do
      expect(presenter.repository).to eq(mock_repository)
    end
  end
end
