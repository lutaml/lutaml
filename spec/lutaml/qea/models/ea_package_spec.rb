# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_package"

RSpec.describe Lutaml::Qea::Models::EaPackage do
  describe ".primary_key_column" do
    it "returns :package_id" do
      expect(described_class.primary_key_column).to eq(:package_id)
    end
  end

  describe ".table_name" do
    it "returns 't_package'" do
      expect(described_class.table_name).to eq("t_package")
    end
  end

  describe "#primary_key" do
    it "returns package_id value" do
      pkg = described_class.new(package_id: 123)
      expect(pkg.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing package_id" do
      pkg = described_class.new(package_id: 456)
      expect(pkg.package_id).to eq(456)
    end

    it "allows reading and writing name" do
      pkg = described_class.new(name: "MyPackage")
      expect(pkg.name).to eq("MyPackage")
    end

    it "allows reading and writing parent_id" do
      pkg = described_class.new(parent_id: 789)
      expect(pkg.parent_id).to eq(789)
    end

    it "allows reading and writing ea_guid" do
      pkg = described_class.new(ea_guid: "{GUID}")
      expect(pkg.ea_guid).to eq("{GUID}")
    end
  end

  describe "#controlled?" do
    it "returns true when iscontrolled is 1" do
      pkg = described_class.new(iscontrolled: 1)
      expect(pkg).to be_controlled
    end

    it "returns false when iscontrolled is 0" do
      pkg = described_class.new(iscontrolled: 0)
      expect(pkg).not_to be_controlled
    end

    it "returns false when iscontrolled is nil" do
      pkg = described_class.new(iscontrolled: nil)
      expect(pkg).not_to be_controlled
    end
  end

  describe "#protected?" do
    it "returns true when protected is 1" do
      pkg = described_class.new(protected: 1)
      expect(pkg).to be_protected
    end

    it "returns false when protected is 0" do
      pkg = described_class.new(protected: 0)
      expect(pkg).not_to be_protected
    end

    it "returns false when protected is nil" do
      pkg = described_class.new(protected: nil)
      expect(pkg).not_to be_protected
    end
  end

  describe "#use_dtd?" do
    it "returns true when usedtd is 1" do
      pkg = described_class.new(usedtd: 1)
      expect(pkg).to be_use_dtd
    end

    it "returns false when usedtd is 0" do
      pkg = described_class.new(usedtd: 0)
      expect(pkg).not_to be_use_dtd
    end
  end

  describe "#log_xml?" do
    it "returns true when logxml is 1" do
      pkg = described_class.new(logxml: 1)
      expect(pkg).to be_log_xml
    end

    it "returns false when logxml is 0" do
      pkg = described_class.new(logxml: 0)
      expect(pkg).not_to be_log_xml
    end
  end

  describe "#root?" do
    it "returns true when parent_id is nil" do
      pkg = described_class.new(parent_id: nil)
      expect(pkg).to be_root
    end

    it "returns true when parent_id is 0" do
      pkg = described_class.new(parent_id: 0)
      expect(pkg).to be_root
    end

    it "returns false when parent_id is non-zero" do
      pkg = described_class.new(parent_id: 123)
      expect(pkg).not_to be_root
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row", :aggregate_failures do
      row = {
        "Package_ID" => 123,
        "Name" => "MyPackage",
        "Parent_ID" => 456,
        "ea_guid" => "{GUID}",
      }

      pkg = described_class.from_db_row(row)

      expect(pkg.package_id).to eq(123)
      expect(pkg.name).to eq("MyPackage")
      expect(pkg.parent_id).to eq(456)
      expect(pkg.ea_guid).to eq("{GUID}")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end
