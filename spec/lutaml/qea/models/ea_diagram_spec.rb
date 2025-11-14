# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/models/ea_diagram"

RSpec.describe Lutaml::Qea::Models::EaDiagram do
  describe ".primary_key_column" do
    it "returns :diagram_id" do
      expect(described_class.primary_key_column).to eq(:diagram_id)
    end
  end

  describe ".table_name" do
    it "returns 't_diagram'" do
      expect(described_class.table_name).to eq("t_diagram")
    end
  end

  describe "#primary_key" do
    it "returns diagram_id value" do
      diagram = described_class.new(diagram_id: 123)
      expect(diagram.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing diagram_id" do
      diagram = described_class.new(diagram_id: 456)
      expect(diagram.diagram_id).to eq(456)
    end

    it "allows reading and writing name" do
      diagram = described_class.new(name: "MyDiagram")
      expect(diagram.name).to eq("MyDiagram")
    end

    it "allows reading and writing package_id" do
      diagram = described_class.new(package_id: 789)
      expect(diagram.package_id).to eq(789)
    end

    it "allows reading and writing diagram_type" do
      diagram = described_class.new(diagram_type: "Logical")
      expect(diagram.diagram_type).to eq("Logical")
    end

    it "allows reading and writing ea_guid" do
      diagram = described_class.new(ea_guid: "{GUID}")
      expect(diagram.ea_guid).to eq("{GUID}")
    end
  end

  describe "#show_details?" do
    it "returns true when showdetails is 1" do
      diagram = described_class.new(showdetails: 1)
      expect(diagram).to be_show_details
    end

    it "returns false when showdetails is 0" do
      diagram = described_class.new(showdetails: 0)
      expect(diagram).not_to be_show_details
    end
  end

  describe "#show_foreign?" do
    it "returns true when showforeign is 1" do
      diagram = described_class.new(showforeign: 1)
      expect(diagram).to be_show_foreign
    end

    it "returns false when showforeign is 0" do
      diagram = described_class.new(showforeign: 0)
      expect(diagram).not_to be_show_foreign
    end
  end

  describe "#show_border?" do
    it "returns true when showborder is 1" do
      diagram = described_class.new(showborder: 1)
      expect(diagram).to be_show_border
    end

    it "returns false when showborder is 0" do
      diagram = described_class.new(showborder: 0)
      expect(diagram).not_to be_show_border
    end
  end

  describe "#show_package_contents?" do
    it "returns true when showpackagecontents is 1" do
      diagram = described_class.new(showpackagecontents: 1)
      expect(diagram).to be_show_package_contents
    end

    it "returns false when showpackagecontents is 0" do
      diagram = described_class.new(showpackagecontents: 0)
      expect(diagram).not_to be_show_package_contents
    end
  end

  describe "#locked?" do
    it "returns true when locked is 1" do
      diagram = described_class.new(locked: 1)
      expect(diagram).to be_locked
    end

    it "returns false when locked is 0" do
      diagram = described_class.new(locked: 0)
      expect(diagram).not_to be_locked
    end
  end

  describe "#portrait?" do
    it "returns true when orientation is 'P'" do
      diagram = described_class.new(orientation: "P")
      expect(diagram).to be_portrait
    end

    it "returns false when orientation is 'L'" do
      diagram = described_class.new(orientation: "L")
      expect(diagram).not_to be_portrait
    end
  end

  describe "#landscape?" do
    it "returns true when orientation is 'L'" do
      diagram = described_class.new(orientation: "L")
      expect(diagram).to be_landscape
    end

    it "returns false when orientation is 'P'" do
      diagram = described_class.new(orientation: "P")
      expect(diagram).not_to be_landscape
    end
  end

  describe "#class_diagram?" do
    it "returns true when diagram_type is 'Logical'" do
      diagram = described_class.new(diagram_type: "Logical")
      expect(diagram).to be_class_diagram
    end

    it "returns false when diagram_type is not 'Logical'" do
      diagram = described_class.new(diagram_type: "Sequence")
      expect(diagram).not_to be_class_diagram
    end
  end

  describe "#use_case_diagram?" do
    it "returns true when diagram_type is 'Use Case'" do
      diagram = described_class.new(diagram_type: "Use Case")
      expect(diagram).to be_use_case_diagram
    end

    it "returns false when diagram_type is not 'Use Case'" do
      diagram = described_class.new(diagram_type: "Logical")
      expect(diagram).not_to be_use_case_diagram
    end
  end

  describe "#sequence_diagram?" do
    it "returns true when diagram_type is 'Sequence'" do
      diagram = described_class.new(diagram_type: "Sequence")
      expect(diagram).to be_sequence_diagram
    end

    it "returns false when diagram_type is not 'Sequence'" do
      diagram = described_class.new(diagram_type: "Logical")
      expect(diagram).not_to be_sequence_diagram
    end
  end

  describe "#activity_diagram?" do
    it "returns true when diagram_type is 'Activity'" do
      diagram = described_class.new(diagram_type: "Activity")
      expect(diagram).to be_activity_diagram
    end

    it "returns false when diagram_type is not 'Activity'" do
      diagram = described_class.new(diagram_type: "Logical")
      expect(diagram).not_to be_activity_diagram
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row" do
      row = {
        "Diagram_ID" => 123,
        "Package_ID" => 456,
        "Name" => "MyDiagram",
        "Diagram_Type" => "Logical",
        "ea_guid" => "{GUID}",
      }

      diagram = described_class.from_db_row(row)

      expect(diagram.diagram_id).to eq(123)
      expect(diagram.package_id).to eq(456)
      expect(diagram.name).to eq("MyDiagram")
      expect(diagram.diagram_type).to eq("Logical")
      expect(diagram.ea_guid).to eq("{GUID}")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end