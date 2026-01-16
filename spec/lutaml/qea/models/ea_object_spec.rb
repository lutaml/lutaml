# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_object"

RSpec.describe Lutaml::Qea::Models::EaObject do
  describe ".primary_key_column" do
    it "returns :ea_object_id" do
      expect(described_class.primary_key_column).to eq(:ea_object_id)
    end
  end

  describe ".table_name" do
    it "returns 't_object'" do
      expect(described_class.table_name).to eq("t_object")
    end
  end

  describe "#primary_key" do
    it "returns ea_object_id value" do
      obj = described_class.new(ea_object_id: 123)
      expect(obj.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing ea_object_id" do
      obj = described_class.new(ea_object_id: 456)
      expect(obj.ea_object_id).to eq(456)
    end

    it "allows reading and writing object_type" do
      obj = described_class.new(object_type: "Class")
      expect(obj.object_type).to eq("Class")
    end

    it "allows reading and writing name" do
      obj = described_class.new(name: "MyClass")
      expect(obj.name).to eq("MyClass")
    end

    it "allows reading and writing package_id" do
      obj = described_class.new(package_id: 789)
      expect(obj.package_id).to eq(789)
    end

    it "allows reading and writing ea_guid" do
      obj = described_class
        .new(ea_guid: "{12345678-1234-1234-1234-123456789012}")
      expect(obj.ea_guid).to eq("{12345678-1234-1234-1234-123456789012}")
    end

    it "allows reading and writing stereotype" do
      obj = described_class.new(stereotype: "entity")
      expect(obj.stereotype).to eq("entity")
    end
  end

  describe "#abstract?" do
    it "returns true when abstract is '1'" do
      obj = described_class.new(abstract: "1")
      expect(obj).to be_abstract
    end

    it "returns false when abstract is '0'" do
      obj = described_class.new(abstract: "0")
      expect(obj).not_to be_abstract
    end

    it "returns false when abstract is nil" do
      obj = described_class.new(abstract: nil)
      expect(obj).not_to be_abstract
    end
  end

  describe "#uml_class?" do
    it "returns true when object_type is 'Class'" do
      obj = described_class.new(object_type: "Class")
      expect(obj).to be_uml_class
    end

    it "returns false when object_type is not 'Class'" do
      obj = described_class.new(object_type: "Interface")
      expect(obj).not_to be_uml_class
    end
  end

  describe "#interface?" do
    it "returns true when object_type is 'Interface'" do
      obj = described_class.new(object_type: "Interface")
      expect(obj).to be_interface
    end

    it "returns false when object_type is not 'Interface'" do
      obj = described_class.new(object_type: "Class")
      expect(obj).not_to be_interface
    end
  end

  describe "#component?" do
    it "returns true when object_type is 'Component'" do
      obj = described_class.new(object_type: "Component")
      expect(obj).to be_component
    end

    it "returns false when object_type is not 'Component'" do
      obj = described_class.new(object_type: "Class")
      expect(obj).not_to be_component
    end
  end

  describe "#package?" do
    it "returns true when object_type is 'Package'" do
      obj = described_class.new(object_type: "Package")
      expect(obj).to be_package
    end

    it "returns false when object_type is not 'Package'" do
      obj = described_class.new(object_type: "Class")
      expect(obj).not_to be_package
    end
  end

  describe "#enumeration?" do
    it "returns true when object_type is 'Enumeration'" do
      obj = described_class.new(object_type: "Enumeration")
      expect(obj).to be_enumeration
    end

    it "returns false when object_type is not 'Enumeration'" do
      obj = described_class.new(object_type: "Class")
      expect(obj).not_to be_enumeration
    end
  end

  describe "#data_type?" do
    it "returns true when object_type is 'DataType'" do
      obj = described_class.new(object_type: "DataType")
      expect(obj).to be_data_type
    end

    it "returns false when object_type is not 'DataType'" do
      obj = described_class.new(object_type: "Class")
      expect(obj).not_to be_data_type
    end
  end

  describe "#root?" do
    it "returns true when isroot is 1" do
      obj = described_class.new(isroot: 1)
      expect(obj).to be_root
    end

    it "returns false when isroot is 0" do
      obj = described_class.new(isroot: 0)
      expect(obj).not_to be_root
    end

    it "returns false when isroot is nil" do
      obj = described_class.new(isroot: nil)
      expect(obj).not_to be_root
    end
  end

  describe "#leaf?" do
    it "returns true when isleaf is 1" do
      obj = described_class.new(isleaf: 1)
      expect(obj).to be_leaf
    end

    it "returns false when isleaf is 0" do
      obj = described_class.new(isleaf: 0)
      expect(obj).not_to be_leaf
    end

    it "returns false when isleaf is nil" do
      obj = described_class.new(isleaf: nil)
      expect(obj).not_to be_leaf
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row" do
      row = {
        "Object_ID" => 123,
        "Object_Type" => "Class",
        "Name" => "MyClass",
        "Package_ID" => 456,
        "ea_guid" => "{GUID}",
        "Abstract" => "1",
      }

      obj = described_class.from_db_row(row)

      expect(obj.ea_object_id).to eq(123)
      expect(obj.object_type).to eq("Class")
      expect(obj.name).to eq("MyClass")
      expect(obj.package_id).to eq(456)
      expect(obj.ea_guid).to eq("{GUID}")
      expect(obj.abstract).to eq("1")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end