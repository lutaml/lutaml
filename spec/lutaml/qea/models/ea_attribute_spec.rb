# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_attribute"

RSpec.describe Lutaml::Qea::Models::EaAttribute do
  describe ".primary_key_column" do
    it "returns :id" do
      expect(described_class.primary_key_column).to eq(:id)
    end
  end

  describe ".table_name" do
    it "returns 't_attribute'" do
      expect(described_class.table_name).to eq("t_attribute")
    end
  end

  describe "#primary_key" do
    it "returns id value" do
      attr = described_class.new(id: 123)
      expect(attr.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing id" do
      attr = described_class.new(id: 456)
      expect(attr.id).to eq(456)
    end

    it "allows reading and writing ea_object_id" do
      attr = described_class.new(ea_object_id: 789)
      expect(attr.ea_object_id).to eq(789)
    end

    it "allows reading and writing name" do
      attr = described_class.new(name: "myAttribute")
      expect(attr.name).to eq("myAttribute")
    end

    it "allows reading and writing type" do
      attr = described_class.new(type: "String")
      expect(attr.type).to eq("String")
    end

    it "allows reading and writing scope" do
      attr = described_class.new(scope: "private")
      expect(attr.scope).to eq("private")
    end

    it "allows reading and writing stereotype" do
      attr = described_class.new(stereotype: "property")
      expect(attr.stereotype).to eq("property")
    end
  end

  describe "#static?" do
    it "returns true when isstatic is 1" do
      attr = described_class.new(isstatic: 1)
      expect(attr).to be_static
    end

    it "returns false when isstatic is 0" do
      attr = described_class.new(isstatic: 0)
      expect(attr).not_to be_static
    end

    it "returns false when isstatic is nil" do
      attr = described_class.new(isstatic: nil)
      expect(attr).not_to be_static
    end
  end

  describe "#collection?" do
    it "returns true when iscollection is 1" do
      attr = described_class.new(iscollection: 1)
      expect(attr).to be_collection
    end

    it "returns false when iscollection is 0" do
      attr = described_class.new(iscollection: 0)
      expect(attr).not_to be_collection
    end
  end

  describe "#ordered?" do
    it "returns true when isordered is 1" do
      attr = described_class.new(isordered: 1)
      expect(attr).to be_ordered
    end

    it "returns false when isordered is 0" do
      attr = described_class.new(isordered: 0)
      expect(attr).not_to be_ordered
    end
  end

  describe "#allow_duplicates?" do
    it "returns true when allowduplicates is 1" do
      attr = described_class.new(allowduplicates: 1)
      expect(attr).to be_allow_duplicates
    end

    it "returns false when allowduplicates is 0" do
      attr = described_class.new(allowduplicates: 0)
      expect(attr).not_to be_allow_duplicates
    end
  end

  describe "#constant?" do
    it "returns true when const is 1" do
      attr = described_class.new(const: 1)
      expect(attr).to be_constant
    end

    it "returns false when const is 0" do
      attr = described_class.new(const: 0)
      expect(attr).not_to be_constant
    end
  end

  describe "#public?" do
    it "returns true when scope is 'Public'" do
      attr = described_class.new(scope: "Public")
      expect(attr).to be_public
    end

    it "returns true when scope is 'public'" do
      attr = described_class.new(scope: "public")
      expect(attr).to be_public
    end

    it "returns false when scope is 'Private'" do
      attr = described_class.new(scope: "Private")
      expect(attr).not_to be_public
    end
  end

  describe "#private?" do
    it "returns true when scope is 'Private'" do
      attr = described_class.new(scope: "Private")
      expect(attr).to be_private
    end

    it "returns true when scope is 'private'" do
      attr = described_class.new(scope: "private")
      expect(attr).to be_private
    end

    it "returns false when scope is 'Public'" do
      attr = described_class.new(scope: "Public")
      expect(attr).not_to be_private
    end
  end

  describe "#protected?" do
    it "returns true when scope is 'Protected'" do
      attr = described_class.new(scope: "Protected")
      expect(attr).to be_protected
    end

    it "returns true when scope is 'protected'" do
      attr = described_class.new(scope: "protected")
      expect(attr).to be_protected
    end

    it "returns false when scope is 'Public'" do
      attr = described_class.new(scope: "Public")
      expect(attr).not_to be_protected
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row", :aggregate_failures do
      row = {
        "ID" => 123,
        "Object_ID" => 456,
        "Name" => "myAttribute",
        "Type" => "Integer",
        "Scope" => "private",
        "Stereotype" => "property",
      }

      attr = described_class.from_db_row(row)

      expect(attr.id).to eq(123)
      expect(attr.ea_object_id).to eq(456)
      expect(attr.name).to eq("myAttribute")
      expect(attr.type).to eq("Integer")
      expect(attr.scope).to eq("private")
      expect(attr.stereotype).to eq("property")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end
