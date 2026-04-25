# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_xref"

RSpec.describe Lutaml::Qea::Models::EaXref do
  describe ".primary_key_column" do
    it "returns :xref_id" do
      expect(described_class.primary_key_column).to eq(:xref_id)
    end
  end

  describe ".table_name" do
    it "returns 't_xref'" do
      expect(described_class.table_name).to eq("t_xref")
    end
  end

  describe "#primary_key" do
    it "returns xref_id value" do
      xref = described_class.new(xref_id: "{GUID-123}")
      expect(xref.primary_key).to eq("{GUID-123}")
    end
  end

  describe "attribute access" do
    it "allows reading and writing xref_id" do
      xref = described_class.new(xref_id: "{GUID-456}")
      expect(xref.xref_id).to eq("{GUID-456}")
    end

    it "allows reading and writing name" do
      xref = described_class.new(name: "Stereotypes")
      expect(xref.name).to eq("Stereotypes")
    end

    it "allows reading and writing xref_type" do
      xref = described_class.new(xref_type: "element property")
      expect(xref.xref_type).to eq("element property")
    end

    it "allows reading and writing client" do
      xref = described_class.new(client: "{CLIENT-GUID}")
      expect(xref.client).to eq("{CLIENT-GUID}")
    end

    it "allows reading and writing supplier" do
      xref = described_class.new(supplier: "{SUPPLIER-GUID}")
      expect(xref.supplier).to eq("{SUPPLIER-GUID}")
    end

    it "allows reading and writing description" do
      xref = described_class.new(description: "@STEREO;Name=FeatureType;")
      expect(xref.description).to eq("@STEREO;Name=FeatureType;")
    end
  end

  describe "aliases" do
    it "provides id alias for xref_id" do
      xref = described_class.new(xref_id: "{GUID-789}")
      expect(xref.id).to eq("{GUID-789}")
    end

    it "provides type alias for xref_type" do
      xref = described_class.new(xref_type: "connector property")
      expect(xref.type).to eq("connector property")
    end
  end

  describe "#stereotype?" do
    it "returns true when name is Stereotypes" do
      xref = described_class.new(name: "Stereotypes")
      expect(xref).to be_stereotype
    end

    it "returns true when description contains @STEREO" do
      xref = described_class.new(description: "@STEREO;Name=Test;")
      expect(xref).to be_stereotype
    end

    it "returns false otherwise" do
      xref = described_class.new(name: "Other", description: "key=value")
      expect(xref).not_to be_stereotype
    end
  end

  describe "#element_property?" do
    it "returns true when xref_type is 'element property'" do
      xref = described_class.new(xref_type: "element property")
      expect(xref).to be_element_property
    end

    it "returns false otherwise" do
      xref = described_class.new(xref_type: "connector property")
      expect(xref).not_to be_element_property
    end
  end

  describe "#connector_property?" do
    it "returns true when xref_type contains 'connector' and 'property'" do
      xref = described_class.new(xref_type: "connectorSrcEnd property")
      expect(xref).to be_connector_property
    end

    it "returns true for 'connector property'" do
      xref = described_class.new(xref_type: "connector property")
      expect(xref).to be_connector_property
    end

    it "returns false otherwise" do
      xref = described_class.new(xref_type: "element property")
      expect(xref).not_to be_connector_property
    end
  end

  describe "#diagram_property?" do
    it "returns true when xref_type is 'diagram properties'" do
      xref = described_class.new(xref_type: "diagram properties")
      expect(xref).to be_diagram_property
    end

    it "returns false otherwise" do
      xref = described_class.new(xref_type: "element property")
      expect(xref).not_to be_diagram_property
    end
  end

  describe "#attribute_property?" do
    it "returns true when xref_type is 'attribute property'" do
      xref = described_class.new(xref_type: "attribute property")
      expect(xref).to be_attribute_property
    end

    it "returns false otherwise" do
      xref = described_class.new(xref_type: "element property")
      expect(xref).not_to be_attribute_property
    end
  end

  describe "#parsed_description" do
    context "with @STEREO format" do
      it "parses stereotype description", :aggregate_failures do
        xref = described_class.new(
          description: "@STEREO;Name=FeatureType;GUID={ABC-123};",
        )

        parsed = xref.parsed_description

        expect(parsed[:format]).to eq(:stereotype)
        expect(parsed[:data][:name]).to eq("FeatureType")
        expect(parsed[:data][:guid]).to eq("{ABC-123}")
      end
    end

    context "with @TAG format" do
      it "parses tag description", :aggregate_failures do
        xref = described_class.new(
          description: "@TAG;Name=author;Value=John;GUID={DEF-456};",
        )

        parsed = xref.parsed_description

        expect(parsed[:format]).to eq(:tag)
        expect(parsed[:data][:name]).to eq("author")
        expect(parsed[:data][:value]).to eq("John")
        expect(parsed[:data][:guid]).to eq("{DEF-456}")
      end
    end

    context "with key=value format" do
      it "parses key-value description", :aggregate_failures do
        xref = described_class.new(
          description: "aggregation=composite;direction=source;",
        )

        parsed = xref.parsed_description

        expect(parsed[:format]).to eq(:key_value)
        expect(parsed[:data][:aggregation]).to eq("composite")
        expect(parsed[:data][:direction]).to eq("source")
      end
    end

    context "with empty description" do
      it "returns empty hash" do
        xref = described_class.new(description: "")
        expect(xref.parsed_description).to eq({})
      end
    end

    context "with nil description" do
      it "returns empty hash" do
        xref = described_class.new(description: nil)
        expect(xref.parsed_description).to eq({})
      end
    end

    it "caches parsed result" do
      xref = described_class.new(description: "@STEREO;Name=Test;")

      first = xref.parsed_description
      second = xref.parsed_description

      expect(first).to equal(second)
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row", :aggregate_failures do
      row = {
        "XrefID" => "{GUID-123}",
        "Name" => "Stereotypes",
        "Type" => "element property",
        "Client" => "{CLIENT-GUID}",
        "Supplier" => "{SUPPLIER-GUID}",
        "Description" => "@STEREO;Name=FeatureType;",
      }

      xref = described_class.from_db_row(row)

      expect(xref.xref_id).to eq("{GUID-123}")
      expect(xref.name).to eq("Stereotypes")
      expect(xref.xref_type).to eq("element property")
      expect(xref.client).to eq("{CLIENT-GUID}")
      expect(xref.supplier).to eq("{SUPPLIER-GUID}")
      expect(xref.description).to eq("@STEREO;Name=FeatureType;")
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
