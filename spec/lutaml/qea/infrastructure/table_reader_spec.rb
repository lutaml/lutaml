# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/infrastructure/database_connection"
require_relative "../../../../lib/lutaml/qea/infrastructure/table_reader"

RSpec.describe Lutaml::Qea::Infrastructure::TableReader do
  let(:test_qea_file) do
    File.expand_path("../../../../examples/qea/test.qea", __dir__)
  end
  let(:connection) { Lutaml::Qea::Infrastructure::DatabaseConnection.new(test_qea_file) }
  let(:database) { connection.connect }
  let(:table_name) { "t_object" }
  let(:reader) { described_class.new(database, table_name) }

  after do
    connection.close if connection.connected?
  end

  describe "#initialize" do
    it "creates a new table reader instance" do
      expect(reader).to be_a(described_class)
      expect(reader.database).to eq(database)
      expect(reader.table_name).to eq(table_name)
    end

    it "raises ArgumentError when database is nil" do
      expect do
        described_class.new(nil, table_name)
      end.to raise_error(ArgumentError, /database cannot be nil/)
    end

    it "raises ArgumentError when table_name is nil" do
      expect do
        described_class.new(database, nil)
      end.to raise_error(ArgumentError, /table_name cannot be nil or empty/)
    end

    it "raises ArgumentError when table_name is empty" do
      expect do
        described_class.new(database, "")
      end.to raise_error(ArgumentError, /table_name cannot be nil or empty/)
    end
  end

  describe "#all" do
    it "returns array of records" do
      results = reader.all
      expect(results).to be_an(Array)
    end

    it "returns records as hashes" do
      results = reader.all(limit: 1)
      if results.any?
        expect(results.first).to be_a(Hash)
      end
    end

    it "respects limit parameter" do
      results = reader.all(limit: 5)
      expect(results.size).to be <= 5
    end

    it "respects offset parameter" do
      all_results = reader.all
      if all_results.size > 2
        offset_results = reader.all(limit: 1, offset: 1)
        expect(offset_results.first).to eq(all_results[1])
      end
    end

    it "returns empty array for empty table" do
      empty_reader = described_class.new(database, "t_authors")
      results = empty_reader.all
      expect(results).to eq([])
    end
  end

  describe "#where" do
    it "filters records by condition" do
      # Find all records first to get a valid value
      all_results = reader.all(limit: 1)
      if all_results.any? && all_results.first["Object_Type"]
        object_type = all_results.first["Object_Type"]
        results = reader.where("Object_Type = ?", object_type)
        expect(results).to be_an(Array)
        results.each do |record|
          expect(record["Object_Type"]).to eq(object_type)
        end
      end
    end

    it "handles multiple conditions" do
      all_results = reader.all(limit: 1)
      if all_results.any?
        obj_type = all_results.first["Object_Type"]
        pkg_id = all_results.first["Package_ID"]
        results = reader.where(
          "Object_Type = ? AND Package_ID = ?",
          obj_type,
          pkg_id,
        )
        results.each do |record|
          expect(record["Object_Type"]).to eq(obj_type)
          expect(record["Package_ID"]).to eq(pkg_id)
        end
      end
    end

    it "respects limit parameter" do
      results = reader.where("Object_ID > ?", 0, limit: 3)
      expect(results.size).to be <= 3
    end

    it "returns empty array when no matches" do
      results = reader.where("Object_ID = ?", -999999)
      expect(results).to eq([])
    end
  end

  describe "#count" do
    it "returns total record count" do
      count = reader.count
      expect(count).to be_an(Integer)
      expect(count).to be >= 0
    end

    it "matches size of all records" do
      count = reader.count
      all_records = reader.all
      expect(all_records.size).to eq(count)
    end
  end

  describe "#count_where" do
    it "counts records matching condition" do
      all_results = reader.all(limit: 1)
      if all_results.any? && all_results.first["Object_Type"]
        obj_type = all_results.first["Object_Type"]
        count = reader.count_where("Object_Type = ?", obj_type)
        expect(count).to be_an(Integer)
        expect(count).to be > 0

        # Verify count matches actual results
        matching = reader.where("Object_Type = ?", obj_type)
        expect(matching.size).to eq(count)
      end
    end

    it "returns 0 when no matches" do
      count = reader.count_where("Object_ID = ?", -999999)
      expect(count).to eq(0)
    end
  end

  describe "#find_by_pk" do
    it "finds record by primary key" do
      all_results = reader.all(limit: 1)
      if all_results.any?
        pk_value = all_results.first["Object_ID"]
        result = reader.find_by_pk("Object_ID", pk_value)
        expect(result).to be_a(Hash)
        expect(result["Object_ID"]).to eq(pk_value)
      end
    end

    it "returns nil when not found" do
      result = reader.find_by_pk("Object_ID", -999999)
      expect(result).to be_nil
    end
  end

  describe "#find_first" do
    it "finds first matching record" do
      all_results = reader.all(limit: 1)
      if all_results.any? && all_results.first["Object_Type"]
        obj_type = all_results.first["Object_Type"]
        result = reader.find_first("Object_Type = ?", obj_type)
        expect(result).to be_a(Hash)
        expect(result["Object_Type"]).to eq(obj_type)
      end
    end

    it "returns nil when not found" do
      result = reader.find_first("Object_ID = ?", -999999)
      expect(result).to be_nil
    end

    it "returns only one record" do
      all_results = reader.all
      if all_results.size > 1
        obj_type = all_results.first["Object_Type"]
        result = reader.find_first("Object_Type = ?", obj_type)
        expect(result).to be_a(Hash)
      end
    end
  end

  describe "#execute_query" do
    it "executes custom SQL query" do
      sql = "SELECT Object_ID, Name FROM #{table_name} LIMIT 5"
      results = reader.execute_query(sql)
      expect(results).to be_an(Array)
    end

    it "handles parameterized queries" do
      sql = "SELECT * FROM #{table_name} WHERE Object_ID > ? LIMIT ?"
      results = reader.execute_query(sql, [0, 5])
      expect(results).to be_an(Array)
      expect(results.size).to be <= 5
    end
  end

  describe "#exists?" do
    it "returns true when records exist" do
      all_results = reader.all(limit: 1)
      if all_results.any?
        pk_value = all_results.first["Object_ID"]
        exists = reader.exists?("Object_ID = ?", pk_value)
        expect(exists).to be true
      end
    end

    it "returns false when no records match" do
      exists = reader.exists?("Object_ID = ?", -999999)
      expect(exists).to be false
    end
  end

  describe "#select" do
    it "selects specific columns" do
      results = reader.select(["Object_ID", "Name"], nil, limit: 5)
      expect(results).to be_an(Array)
      if results.any?
        result = results.first
        expect(result.keys).to match_array(["Object_ID", "Name"])
      end
    end

    it "applies conditions" do
      all_results = reader.all(limit: 1)
      if all_results.any? && all_results.first["Object_Type"]
        obj_type = all_results.first["Object_Type"]
        results = reader.select(
          ["Object_ID", "Name"],
          "Object_Type = ?",
          obj_type,
        )
        results.each do |record|
          expect(record.keys.sort).to eq(["Name", "Object_ID"].sort)
        end
      end
    end

    it "respects limit" do
      results = reader.select(["Object_ID"], nil, limit: 3)
      expect(results.size).to be <= 3
    end
  end

  describe "integration with different tables" do
    context "with t_package table" do
      let(:package_reader) { described_class.new(database, "t_package") }

      it "reads package records" do
        results = package_reader.all(limit: 5)
        expect(results).to be_an(Array)
        if results.any?
          expect(results.first).to have_key("Package_ID")
          expect(results.first).to have_key("Name")
        end
      end

      it "counts packages" do
        count = package_reader.count
        expect(count).to be >= 0
      end
    end

    context "with t_attribute table" do
      let(:attr_reader) { described_class.new(database, "t_attribute") }

      it "reads attribute records" do
        results = attr_reader.all(limit: 5)
        expect(results).to be_an(Array)
        if results.any?
          expect(results.first).to have_key("ID")
          expect(results.first).to have_key("Name")
        end
      end
    end

    context "with t_connector table" do
      let(:conn_reader) { described_class.new(database, "t_connector") }

      it "reads connector records" do
        results = conn_reader.all(limit: 5)
        expect(results).to be_an(Array)
        if results.any?
          expect(results.first).to have_key("Connector_ID")
        end
      end
    end
  end
end
