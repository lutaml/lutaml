# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_operation"

RSpec.describe Lutaml::Qea::Models::EaOperation do
  describe ".primary_key_column" do
    it "returns :operationid" do
      expect(described_class.primary_key_column).to eq(:operationid)
    end
  end

  describe ".table_name" do
    it "returns 't_operation'" do
      expect(described_class.table_name).to eq("t_operation")
    end
  end

  describe "#primary_key" do
    it "returns operationid value" do
      op = described_class.new(operationid: 123)
      expect(op.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing operationid" do
      op = described_class.new(operationid: 456)
      expect(op.operationid).to eq(456)
    end

    it "allows reading and writing ea_object_id" do
      op = described_class.new(ea_object_id: 789)
      expect(op.ea_object_id).to eq(789)
    end

    it "allows reading and writing name" do
      op = described_class.new(name: "myMethod")
      expect(op.name).to eq("myMethod")
    end

    it "allows reading and writing type" do
      op = described_class.new(type: "void")
      expect(op.type).to eq("void")
    end

    it "allows reading and writing scope" do
      op = described_class.new(scope: "public")
      expect(op.scope).to eq("public")
    end

    it "allows reading and writing stereotype" do
      op = described_class.new(stereotype: "method")
      expect(op.stereotype).to eq("method")
    end
  end

  describe "#static?" do
    it "returns true when isstatic is '1'" do
      op = described_class.new(isstatic: "1")
      expect(op).to be_static
    end

    it "returns false when isstatic is '0'" do
      op = described_class.new(isstatic: "0")
      expect(op).not_to be_static
    end

    it "returns false when isstatic is nil" do
      op = described_class.new(isstatic: nil)
      expect(op).not_to be_static
    end
  end

  describe "#abstract?" do
    it "returns true when abstract is '1'" do
      op = described_class.new(abstract: "1")
      expect(op).to be_abstract
    end

    it "returns false when abstract is '0'" do
      op = described_class.new(abstract: "0")
      expect(op).not_to be_abstract
    end

    it "returns false when abstract is nil" do
      op = described_class.new(abstract: nil)
      expect(op).not_to be_abstract
    end
  end

  describe "#synchronized?" do
    it "returns true when synchronized is '1'" do
      op = described_class.new(synchronized: "1")
      expect(op).to be_synchronized
    end

    it "returns false when synchronized is '0'" do
      op = described_class.new(synchronized: "0")
      expect(op).not_to be_synchronized
    end
  end

  describe "#pure?" do
    it "returns true when pure is 1" do
      op = described_class.new(pure: 1)
      expect(op).to be_pure
    end

    it "returns false when pure is 0" do
      op = described_class.new(pure: 0)
      expect(op).not_to be_pure
    end
  end

  describe "#query?" do
    it "returns true when isquery is 1" do
      op = described_class.new(isquery: 1)
      expect(op).to be_query
    end

    it "returns false when isquery is 0" do
      op = described_class.new(isquery: 0)
      expect(op).not_to be_query
    end
  end

  describe "#root?" do
    it "returns true when isroot is 1" do
      op = described_class.new(isroot: 1)
      expect(op).to be_root
    end

    it "returns false when isroot is 0" do
      op = described_class.new(isroot: 0)
      expect(op).not_to be_root
    end
  end

  describe "#leaf?" do
    it "returns true when isleaf is 1" do
      op = described_class.new(isleaf: 1)
      expect(op).to be_leaf
    end

    it "returns false when isleaf is 0" do
      op = described_class.new(isleaf: 0)
      expect(op).not_to be_leaf
    end
  end

  describe "#constant?" do
    it "returns true when const is 1" do
      op = described_class.new(const: 1)
      expect(op).to be_constant
    end

    it "returns false when const is 0" do
      op = described_class.new(const: 0)
      expect(op).not_to be_constant
    end
  end

  describe "#public?" do
    it "returns true when scope is 'Public'" do
      op = described_class.new(scope: "Public")
      expect(op).to be_public
    end

    it "returns true when scope is 'public'" do
      op = described_class.new(scope: "public")
      expect(op).to be_public
    end

    it "returns false when scope is 'Private'" do
      op = described_class.new(scope: "Private")
      expect(op).not_to be_public
    end
  end

  describe "#private?" do
    it "returns true when scope is 'Private'" do
      op = described_class.new(scope: "Private")
      expect(op).to be_private
    end

    it "returns true when scope is 'private'" do
      op = described_class.new(scope: "private")
      expect(op).to be_private
    end

    it "returns false when scope is 'Public'" do
      op = described_class.new(scope: "Public")
      expect(op).not_to be_private
    end
  end

  describe "#protected?" do
    it "returns true when scope is 'Protected'" do
      op = described_class.new(scope: "Protected")
      expect(op).to be_protected
    end

    it "returns true when scope is 'protected'" do
      op = described_class.new(scope: "protected")
      expect(op).to be_protected
    end

    it "returns false when scope is 'Public'" do
      op = described_class.new(scope: "Public")
      expect(op).not_to be_protected
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row" do
      row = {
        "OperationID" => 123,
        "Object_ID" => 456,
        "Name" => "myMethod",
        "Type" => "String",
        "Scope" => "public",
        "Stereotype" => "method",
      }

      op = described_class.from_db_row(row)

      expect(op.operationid).to eq(123)
      expect(op.ea_object_id).to eq(456)
      expect(op.name).to eq("myMethod")
      expect(op.type).to eq("String")
      expect(op.scope).to eq("public")
      expect(op.stereotype).to eq("method")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end
