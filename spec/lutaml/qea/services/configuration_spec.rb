# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/services/configuration"

RSpec.describe Lutaml::Qea::Services::Configuration do
  let(:config_path) { File.expand_path("../../../../config/qea_schema.yml", __dir__) }

  describe ".load" do
    it "loads configuration from YAML file" do
      config = described_class.load(config_path)
      expect(config).to be_a(described_class)
    end

    it "uses default path when none provided" do
      config = described_class.load
      expect(config).to be_a(described_class)
    end

    it "raises error when file not found" do
      expect do
        described_class.load("nonexistent.yml")
      end.to raise_error(Errno::ENOENT, /Configuration file not found/)
    end
  end

  describe ".default_config_path" do
    it "returns path to default config file" do
      path = described_class.default_config_path
      expect(path).to end_with("config/qea_schema.yml")
      expect(File.exist?(path)).to be true
    end
  end

  describe "loaded configuration" do
    let(:config) { described_class.load(config_path) }

    describe "basic attributes" do
      it "has version" do
        expect(config.version).to be_a(String)
        expect(config.version).not_to be_empty
      end

      it "has description" do
        expect(config.description).to be_a(String)
      end

      it "has boolean_fields list" do
        expect(config.boolean_fields).to be_an(Array)
        expect(config.boolean_fields).to include("IsStatic", "IsCollection")
      end

      it "has null_handling configuration" do
        expect(config.null_handling).to be_a(described_class::NullHandling)
      end

      it "has tables configuration" do
        expect(config.tables).to be_an(Array)
        expect(config.tables).not_to be_empty
        expect(config.tables.first).to be_a(described_class::TableDefinition)
      end
    end

    describe "#enabled_tables" do
      it "returns array of enabled table definitions" do
        tables = config.enabled_tables
        expect(tables).to be_an(Array)
        expect(tables).to all(be_a(described_class::TableDefinition))
      end

      it "includes expected EA tables" do
        table_names = config.enabled_tables.map(&:table_name)
        expect(table_names).to include("t_object", "t_attribute", "t_package")
      end

      it "only returns enabled tables" do
        tables = config.enabled_tables
        tables.each do |table|
          expect(table.enabled).to be true
        end
      end
    end

    describe "#table_config_for" do
      it "returns table configuration by name" do
        table = config.table_config_for("t_object")
        expect(table).to be_a(described_class::TableDefinition)
        expect(table.table_name).to eq("t_object")
      end

      it "returns nil for non-existent table" do
        table = config.table_config_for("nonexistent_table")
        expect(table).to be_nil
      end

      it "returns table with correct attributes" do
        table = config.table_config_for("t_object")
        expect(table.primary_key).to eq("Object_ID")
        expect(table.collection_name).to eq("objects")
        expect(table.enabled).to be true
      end
    end

    describe "#table_enabled?" do
      it "returns true for enabled table" do
        expect(config.table_enabled?("t_object")).to be true
      end

      it "returns false for non-existent table" do
        expect(config.table_enabled?("nonexistent")).to be false
      end
    end

    describe "#enabled_table_names" do
      it "returns array of table names" do
        names = config.enabled_table_names
        expect(names).to be_an(Array)
        expect(names).to all(be_a(String))
      end

      it "includes core EA tables" do
        names = config.enabled_table_names
        expect(names).to include("t_object", "t_package", "t_attribute")
      end
    end

    describe "#boolean_field?" do
      it "returns true for boolean fields" do
        expect(config.boolean_field?("IsStatic")).to be true
        expect(config.boolean_field?("IsCollection")).to be true
      end

      it "returns false for non-boolean fields" do
        expect(config.boolean_field?("Name")).to be false
        expect(config.boolean_field?("Object_ID")).to be false
      end
    end

    describe "#primary_key_for" do
      it "returns primary key for t_object" do
        pk = config.primary_key_for("t_object")
        expect(pk).to eq("Object_ID")
      end

      it "returns primary key for t_package" do
        pk = config.primary_key_for("t_package")
        expect(pk).to eq("Package_ID")
      end

      it "returns primary key for t_attribute" do
        pk = config.primary_key_for("t_attribute")
        expect(pk).to eq("ID")
      end

      it "returns nil for non-existent table" do
        pk = config.primary_key_for("nonexistent")
        expect(pk).to be_nil
      end
    end

    describe "#collection_name_for" do
      it "returns collection name for t_object" do
        name = config.collection_name_for("t_object")
        expect(name).to eq("objects")
      end

      it "returns collection name for t_package" do
        name = config.collection_name_for("t_package")
        expect(name).to eq("packages")
      end

      it "returns nil for non-existent table" do
        name = config.collection_name_for("nonexistent")
        expect(name).to be_nil
      end
    end

    describe "#convert_empty_string" do
      context "when empty_string_as_null is true" do
        it "converts empty string to nil" do
          result = config.convert_empty_string("")
          expect(result).to be_nil
        end

        it "converts nil to nil" do
          result = config.convert_empty_string(nil)
          expect(result).to be_nil
        end

        it "keeps non-empty strings" do
          result = config.convert_empty_string("test")
          expect(result).to eq("test")
        end
      end
    end

    describe "#zero_as_null?" do
      it "returns boolean value" do
        result = config.zero_as_null?
        expect([true, false]).to include(result)
      end
    end
  end

  describe "TableDefinition" do
    let(:config) { described_class.load(config_path) }
    let(:table) { config.table_config_for("t_object") }

    describe "#columns" do
      it "has column definitions" do
        expect(table.columns).to be_an(Array)
        expect(table.columns).not_to be_empty
        expect(table.columns.first).to be_a(described_class::ColumnDefinition)
      end

      it "includes Object_ID column" do
        column = table.columns.find { |c| c.name == "Object_ID" }
        expect(column).not_to be_nil
        expect(column.type).to eq("INTEGER")
        expect(column.primary).to be true
      end

      it "includes Name column" do
        column = table.columns.find { |c| c.name == "Name" }
        expect(column).not_to be_nil
        expect(column.type).to eq("TEXT")
      end
    end

    describe "#column_for" do
      it "returns column definition by name" do
        column = table.column_for("Object_ID")
        expect(column).to be_a(described_class::ColumnDefinition)
        expect(column.name).to eq("Object_ID")
      end

      it "returns nil for non-existent column" do
        column = table.column_for("nonexistent")
        expect(column).to be_nil
      end
    end

    describe "#boolean_column?" do
      it "returns true for boolean columns" do
        # IsRoot is marked as boolean in config
        expect(table.boolean_column?("IsRoot")).to be true
      end

      it "returns false for non-boolean columns" do
        expect(table.boolean_column?("Name")).to be false
        expect(table.boolean_column?("Object_ID")).to be false
      end
    end
  end

  describe "ColumnDefinition" do
    let(:config) { described_class.load(config_path) }
    let(:table) { config.table_config_for("t_object") }
    let(:column) { table.column_for("Object_ID") }

    it "has name attribute" do
      expect(column.name).to eq("Object_ID")
    end

    it "has type attribute" do
      expect(column.type).to eq("INTEGER")
    end

    it "has primary attribute" do
      expect(column.primary).to be true
    end

    it "has nullable attribute" do
      expect([true, false]).to include(column.nullable)
    end

    it "has boolean attribute" do
      expect([true, false]).to include(column.boolean)
    end
  end

  describe "NullHandling" do
    let(:config) { described_class.load(config_path) }
    let(:null_handling) { config.null_handling }

    it "has strategy" do
      expect(null_handling.strategy).to be_a(String)
    end

    it "has empty_string_as_null setting" do
      expect([true, false]).to include(null_handling.empty_string_as_null)
    end

    it "has zero_as_null setting" do
      expect([true, false]).to include(null_handling.zero_as_null)
    end
  end

  describe "integration" do
    it "can load and access complete configuration" do
      config = described_class.load

      # Verify structure
      expect(config.enabled_tables.size).to be > 0

      # Verify each enabled table has required attributes
      config.enabled_tables.each do |table|
        expect(table.table_name).not_to be_empty
        expect(table.primary_key).not_to be_nil
        expect(table.collection_name).not_to be_nil
        expect(table.columns).not_to be_empty
      end

      # Verify we can look up tables
      expect(config.table_enabled?("t_object")).to be true
      expect(config.primary_key_for("t_object")).to eq("Object_ID")
      expect(config.collection_name_for("t_object")).to eq("objects")
    end

    it "provides consistent data across methods" do
      config = described_class.load

      enabled_names = config.enabled_table_names
      enabled_tables = config.enabled_tables

      expect(enabled_names.size).to eq(enabled_tables.size)

      enabled_names.each do |name|
        expect(config.table_enabled?(name)).to be true
        expect(config.table_config_for(name)).not_to be_nil
      end
    end
  end
end