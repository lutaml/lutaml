# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/infrastructure/database_connection"
require_relative "../../../../lib/lutaml/qea/infrastructure/schema_reader"

RSpec.describe Lutaml::Qea::Infrastructure::SchemaReader do
  let(:test_qea_file) do
    File.expand_path("../../../../examples/qea/test.qea", __dir__)
  end
  let(:connection) { Lutaml::Qea::Infrastructure::DatabaseConnection.new(test_qea_file) }
  let(:database) { connection.connect }
  let(:reader) { described_class.new(database) }

  after do
    connection.close if connection.connected?
  end

  describe "#initialize" do
    it "creates a new schema reader instance", :aggregate_failures do
      expect(reader).to be_a(described_class)
      expect(reader.database).to eq(database)
    end

    it "raises ArgumentError when database is nil" do
      expect do
        described_class.new(nil)
      end.to raise_error(ArgumentError,
                         /database cannot be nil/)
    end
  end

  describe "#tables" do
    it "returns list of table names", :aggregate_failures do
      tables = reader.tables
      expect(tables).to be_an(Array)
      expect(tables).not_to be_empty
    end

    it "includes expected EA tables" do
      tables = reader.tables
      expect(tables).to include("t_object", "t_package", "t_attribute",
                                "t_connector")
    end

    it "excludes SQLite system tables by default" do
      tables = reader.tables
      expect(tables).not_to include("sqlite_sequence")
    end

    it "includes system tables when exclude_system is false" do
      tables = reader.tables(exclude_system: false)
      expect(tables).to include("sqlite_sequence")
    end

    it "returns tables in alphabetical order" do
      tables = reader.tables
      expect(tables).to eq(tables.sort)
    end
  end

  describe "#columns" do
    it "returns column information for a table", :aggregate_failures do
      columns = reader.columns("t_object")
      expect(columns).to be_an(Array)
      expect(columns).not_to be_empty
    end

    it "includes column metadata", :aggregate_failures do
      columns = reader.columns("t_object")
      first_col = columns.first

      expect(first_col).to have_key("name")
      expect(first_col).to have_key("type")
      expect(first_col).to have_key("notnull")
      expect(first_col).to have_key("pk")
    end

    it "identifies primary key column", :aggregate_failures do
      columns = reader.columns("t_object")
      pk_column = columns.find { |col| col["pk"] == 1 }

      expect(pk_column).not_to be_nil
      expect(pk_column["name"]).to eq("Object_ID")
    end

    it "returns expected columns for t_object table" do
      column_names = reader.columns("t_object").map { |col| col["name"] }

      expect(column_names).to include(
        "Object_ID",
        "Object_Type",
        "Name",
        "Package_ID",
        "ea_guid",
      )
    end

    it "returns expected columns for t_package table" do
      column_names = reader.columns("t_package").map { |col| col["name"] }

      expect(column_names).to include(
        "Package_ID",
        "Name",
        "Parent_ID",
        "ea_guid",
      )
    end
  end

  describe "#column_names" do
    it "returns array of column names", :aggregate_failures do
      names = reader.column_names("t_object")
      expect(names).to be_an(Array)
      expect(names).to all(be_a(String))
    end

    it "includes expected column names" do
      names = reader.column_names("t_object")
      expect(names).to include("Object_ID", "Name", "Object_Type")
    end

    it "does not include metadata" do
      names = reader.column_names("t_object")
      names.each do |name|
        expect(name).not_to match(/^(cid|type|notnull|pk)$/)
      end
    end
  end

  describe "#table_exists?" do
    it "returns true for existing table" do
      expect(reader.table_exists?("t_object")).to be true
    end

    it "returns false for non-existing table" do
      expect(reader.table_exists?("nonexistent_table")).to be false
    end

    it "is case-sensitive" do
      expect(reader.table_exists?("T_OBJECT")).to be false
    end
  end

  describe "#primary_key" do
    it "returns primary key column name for t_object" do
      pk = reader.primary_key("t_object")
      expect(pk).to eq("Object_ID")
    end

    it "returns primary key column name for t_package" do
      pk = reader.primary_key("t_package")
      expect(pk).to eq("Package_ID")
    end

    it "returns primary key column name for t_attribute" do
      pk = reader.primary_key("t_attribute")
      expect(pk).to eq("ID")
    end

    it "returns nil for table without primary key" do
      # Create a temporary table without PK for testing
      database.execute("CREATE TEMP TABLE temp_no_pk (id INTEGER, name TEXT)")
      pk = reader.primary_key("temp_no_pk")
      expect(pk).to be_nil
    end
  end

  describe "#table_schema" do
    it "returns CREATE TABLE statement", :aggregate_failures do
      schema = reader.table_schema("t_object")
      expect(schema).to be_a(String)
      expect(schema).to start_with("CREATE TABLE")
    end

    it "includes table name in schema" do
      schema = reader.table_schema("t_object")
      expect(schema).to include("t_object")
    end

    it "returns nil for non-existing table" do
      schema = reader.table_schema("nonexistent_table")
      expect(schema).to be_nil
    end
  end

  describe "#indexes" do
    it "returns array of indexes" do
      indexes = reader.indexes("t_object")
      expect(indexes).to be_an(Array)
    end

    it "returns index information with name and sql", :aggregate_failures do
      indexes = reader.indexes("t_object")
      if indexes.any?
        index = indexes.first
        expect(index).to have_key("name")
        expect(index).to have_key("sql")
      end
    end
  end

  describe "#row_count" do
    it "returns integer count", :aggregate_failures do
      count = reader.row_count("t_object")
      expect(count).to be_an(Integer)
      expect(count).to be >= 0
    end

    it "returns 0 for empty tables" do
      # Find an empty table
      empty_table = reader.tables.find do |table|
        reader.row_count(table) == 0
      end

      if empty_table
        expect(reader.row_count(empty_table)).to eq(0)
      end
    end
  end

  describe "#statistics" do
    it "returns hash of table names to counts" do
      stats = reader.statistics
      expect(stats).to be_a(Hash)
    end

    it "includes all tables" do
      stats = reader.statistics
      tables = reader.tables

      tables.each do |table|
        expect(stats).to have_key(table)
      end
    end

    it "has integer values", :aggregate_failures do
      stats = reader.statistics
      stats.each_value do |count|
        expect(count).to be_an(Integer)
        expect(count).to be >= 0
      end
    end

    it "includes expected EA tables in statistics", :aggregate_failures do
      stats = reader.statistics
      expect(stats).to have_key("t_object")
      expect(stats).to have_key("t_package")
      expect(stats).to have_key("t_attribute")
    end
  end

  describe "integration" do
    it "can read complete schema information", :aggregate_failures do
      tables = reader.tables
      expect(tables.size).to be > 10

      tables.first(5).each do |table|
        columns = reader.columns(table)
        expect(columns).not_to be_empty

        column_names = reader.column_names(table)
        expect(column_names.size).to eq(columns.size)

        expect(reader.table_exists?(table)).to be true
        expect(reader.row_count(table)).to be >= 0
      end
    end

    it "provides consistent schema information", :aggregate_failures do
      # Column names should match columns
      table = "t_object"
      columns = reader.columns(table)
      column_names = reader.column_names(table)

      expect(column_names.size).to eq(columns.size)
      columns.each_with_index do |col, idx|
        expect(col["name"]).to eq(column_names[idx])
      end
    end
  end
end
