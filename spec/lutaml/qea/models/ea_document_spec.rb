# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/models/ea_document"

RSpec.describe Lutaml::Qea::Models::EaDocument do
  describe ".primary_key_column" do
    it "returns :doc_id" do
      expect(described_class.primary_key_column).to eq(:doc_id)
    end
  end

  describe ".table_name" do
    it "returns 't_document'" do
      expect(described_class.table_name).to eq("t_document")
    end
  end

  describe "#primary_key" do
    it "returns doc_id value" do
      doc = described_class.new(doc_id: "DOC123")
      expect(doc.primary_key).to eq("DOC123")
    end
  end

  describe "attribute access" do
    it "allows reading and writing doc_id" do
      doc = described_class.new(doc_id: "DOC456")
      expect(doc.doc_id).to eq("DOC456")
    end

    it "allows reading and writing doc_name" do
      doc = described_class.new(doc_name: "StyleTemplate")
      expect(doc.doc_name).to eq("StyleTemplate")
    end

    it "allows reading and writing doc_type" do
      doc = described_class.new(doc_type: "SSDOCSTYLE")
      expect(doc.doc_type).to eq("SSDOCSTYLE")
    end

    it "allows reading and writing str_content" do
      doc = described_class.new(str_content: "Content here")
      expect(doc.str_content).to eq("Content here")
    end

    it "allows reading and writing bin_content" do
      doc = described_class.new(bin_content: "Binary data")
      expect(doc.bin_content).to eq("Binary data")
    end

    it "allows reading and writing element_id" do
      doc = described_class.new(element_id: "EL123")
      expect(doc.element_id).to eq("EL123")
    end
  end

  describe "aliases" do
    it "provides id alias for doc_id" do
      doc = described_class.new(doc_id: "DOC789")
      expect(doc.id).to eq("DOC789")
    end

    it "provides name alias for doc_name" do
      doc = described_class.new(doc_name: "MyDoc")
      expect(doc.name).to eq("MyDoc")
    end

    it "provides type alias for doc_type" do
      doc = described_class.new(doc_type: "SSDOCSTYLE")
      expect(doc.type).to eq("SSDOCSTYLE")
    end
  end

  describe "#style_document?" do
    it "returns true when doc_type is SSDOCSTYLE" do
      doc = described_class.new(doc_type: "SSDOCSTYLE")
      expect(doc).to be_style_document
    end

    it "returns false when doc_type is not SSDOCSTYLE" do
      doc = described_class.new(doc_type: "OTHER")
      expect(doc).not_to be_style_document
    end

    it "returns false when doc_type is nil" do
      doc = described_class.new(doc_type: nil)
      expect(doc).not_to be_style_document
    end
  end

  describe "#has_content?" do
    it "returns true when str_content is present" do
      doc = described_class.new(str_content: "Some content")
      expect(doc).to have_content
    end

    it "returns false when str_content is nil" do
      doc = described_class.new(str_content: nil)
      expect(doc).not_to have_content
    end

    it "returns false when str_content is empty" do
      doc = described_class.new(str_content: "")
      expect(doc).not_to have_content
    end
  end

  describe "#has_binary_content?" do
    it "returns true when bin_content is present" do
      doc = described_class.new(bin_content: "Binary")
      expect(doc).to have_binary_content
    end

    it "returns false when bin_content is nil" do
      doc = described_class.new(bin_content: nil)
      expect(doc).not_to have_binary_content
    end

    it "returns false when bin_content is empty" do
      doc = described_class.new(bin_content: "")
      expect(doc).not_to have_binary_content
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row" do
      row = {
        "DocID" => "DOC123",
        "DocName" => "TestDoc",
        "DocType" => "SSDOCSTYLE",
        "StrContent" => "Content",
        "BinContent" => "Binary",
        "ElementID" => "EL456",
      }

      doc = described_class.from_db_row(row)

      expect(doc.doc_id).to eq("DOC123")
      expect(doc.doc_name).to eq("TestDoc")
      expect(doc.doc_type).to eq("SSDOCSTYLE")
      expect(doc.str_content).to eq("Content")
      expect(doc.bin_content).to eq("Binary")
      expect(doc.element_id).to eq("EL456")
    end

    it "returns nil when row is nil" do
      expect(described_class.from_db_row(nil)).to be_nil
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end