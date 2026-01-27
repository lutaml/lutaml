# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/base_model"

RSpec.describe Lutaml::Qea::Models::BaseModel do
  # Create a concrete test class to test the abstract base
  let(:test_class) do
    Class.new(described_class) do
      attribute :id, Lutaml::Model::Type::Integer
      attribute :name, Lutaml::Model::Type::String

      def self.primary_key_column
        :id
      end

      def self.table_name
        "test_table"
      end
    end
  end

  describe ".primary_key_column" do
    it "raises NotImplementedError when not implemented" do
      expect do
        described_class.primary_key_column
      end.to raise_error(
        NotImplementedError,
        /must implement \.primary_key_column/,
      )
    end

    it "returns the primary key column when implemented" do
      expect(test_class.primary_key_column).to eq(:id)
    end
  end

  describe ".table_name" do
    it "raises NotImplementedError when not implemented" do
      expect do
        described_class.table_name
      end.to raise_error(
        NotImplementedError,
        /must implement \.table_name/,
      )
    end

    it "returns the table name when implemented" do
      expect(test_class.table_name).to eq("test_table")
    end
  end

  describe "#primary_key" do
    it "returns the primary key value" do
      instance = test_class.new(id: 123, name: "Test")
      expect(instance.primary_key).to eq(123)
    end

    it "returns nil when primary key is not set" do
      instance = test_class.new(name: "Test")
      expect(instance.primary_key).to be_nil
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row with string keys" do
      row = { "id" => 456, "name" => "From DB" }
      instance = test_class.from_db_row(row)

      expect(instance).to be_a(test_class)
      expect(instance.id).to eq(456)
      expect(instance.name).to eq("From DB")
    end

    it "creates instance from database row with symbol keys" do
      row = { id: 789, name: "Symbol Keys" }
      instance = test_class.from_db_row(row)

      expect(instance).to be_a(test_class)
      expect(instance.id).to eq(789)
      expect(instance.name).to eq("Symbol Keys")
    end

    it "handles mixed case column names" do
      row = { "ID" => 111, "Name" => "Mixed Case" }
      instance = test_class.from_db_row(row)

      expect(instance).to be_a(test_class)
      expect(instance.id).to eq(111)
      expect(instance.name).to eq("Mixed Case")
    end

    it "returns nil for nil row" do
      expect(test_class.from_db_row(nil)).to be_nil
    end
  end

  describe "inheritance" do
    it "inherits from Lutaml::Model::Serializable" do
      expect(described_class).to be < Lutaml::Model::Serializable
    end
  end
end
