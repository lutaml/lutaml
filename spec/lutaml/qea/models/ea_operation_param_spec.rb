# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_operation_param"

RSpec.describe Lutaml::Qea::Models::EaOperationParam do
  describe ".primary_key_column" do
    it "returns :operationid" do
      expect(described_class.primary_key_column).to eq(:operationid)
    end
  end

  describe ".table_name" do
    it "returns 't_operationparams'" do
      expect(described_class.table_name).to eq("t_operationparams")
    end
  end

  describe "#primary_key" do
    it "returns operationid value" do
      param = described_class.new(operationid: 123, name: "param1")
      expect(param.primary_key).to eq(123)
    end
  end

  describe "#composite_key" do
    it "returns array of [operationid, name]" do
      param = described_class.new(operationid: 456, name: "myParam")
      expect(param.composite_key).to eq([456, "myParam"])
    end
  end

  describe "attribute access" do
    it "allows reading and writing operationid" do
      param = described_class.new(operationid: 789)
      expect(param.operationid).to eq(789)
    end

    it "allows reading and writing name" do
      param = described_class.new(name: "parameter")
      expect(param.name).to eq("parameter")
    end

    it "allows reading and writing type" do
      param = described_class.new(type: "String")
      expect(param.type).to eq("String")
    end

    it "allows reading and writing kind" do
      param = described_class.new(kind: "in")
      expect(param.kind).to eq("in")
    end

    it "allows reading and writing default" do
      param = described_class.new(default: "null")
      expect(param.default).to eq("null")
    end
  end

  describe "#constant?" do
    it "returns true when const is 1" do
      param = described_class.new(const: 1)
      expect(param).to be_constant
    end

    it "returns false when const is 0" do
      param = described_class.new(const: 0)
      expect(param).not_to be_constant
    end

    it "returns false when const is nil" do
      param = described_class.new(const: nil)
      expect(param).not_to be_constant
    end
  end

  describe "#input?" do
    it "returns true when kind is 'in'" do
      param = described_class.new(kind: "in")
      expect(param).to be_input
    end

    it "returns true when kind is 'IN'" do
      param = described_class.new(kind: "IN")
      expect(param).to be_input
    end

    it "returns false when kind is 'out'" do
      param = described_class.new(kind: "out")
      expect(param).not_to be_input
    end
  end

  describe "#output?" do
    it "returns true when kind is 'out'" do
      param = described_class.new(kind: "out")
      expect(param).to be_output
    end

    it "returns true when kind is 'OUT'" do
      param = described_class.new(kind: "OUT")
      expect(param).to be_output
    end

    it "returns false when kind is 'in'" do
      param = described_class.new(kind: "in")
      expect(param).not_to be_output
    end
  end

  describe "#inout?" do
    it "returns true when kind is 'inout'" do
      param = described_class.new(kind: "inout")
      expect(param).to be_inout
    end

    it "returns true when kind is 'INOUT'" do
      param = described_class.new(kind: "INOUT")
      expect(param).to be_inout
    end

    it "returns false when kind is 'in'" do
      param = described_class.new(kind: "in")
      expect(param).not_to be_inout
    end
  end

  describe "#return?" do
    it "returns true when kind is 'return'" do
      param = described_class.new(kind: "return")
      expect(param).to be_return
    end

    it "returns true when kind is 'RETURN'" do
      param = described_class.new(kind: "RETURN")
      expect(param).to be_return
    end

    it "returns false when kind is 'in'" do
      param = described_class.new(kind: "in")
      expect(param).not_to be_return
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row", :aggregate_failures do
      row = {
        "OperationID" => 123,
        "Name" => "myParam",
        "Type" => "Integer",
        "Kind" => "in",
        "Default" => "0",
      }

      param = described_class.from_db_row(row)

      expect(param.operationid).to eq(123)
      expect(param.name).to eq("myParam")
      expect(param.type).to eq("Integer")
      expect(param.kind).to eq("in")
      expect(param.default).to eq("0")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end
