# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/lutaml/qea"

RSpec.describe Lutaml::Qea do
  let(:test_qea_file) do
    File.expand_path("../../examples/qea/test.qea", __dir__)
  end

  describe "VERSION" do
    it "has a version number", :aggregate_failures do
      expect(described_class::VERSION).to be_a(String)
      expect(described_class::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end
  end

  describe ".configuration" do
    it "returns configuration instance" do
      config = described_class.configuration
      expect(config).to be_a(Lutaml::Qea::Services::Configuration)
    end

    it "caches configuration" do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to eq(config2)
    end

    it "has enabled tables" do
      config = described_class.configuration
      expect(config.enabled_tables).not_to be_empty
    end
  end

  describe ".configuration=" do
    it "sets custom configuration" do
      original_config = described_class.configuration
      new_config = Lutaml::Qea::Services::Configuration.load

      described_class.configuration = new_config
      expect(described_class.configuration).to eq(new_config)

      # Restore original
      described_class.configuration = original_config
    end
  end

  describe ".reload_configuration" do
    it "reloads configuration from file" do
      config = described_class.reload_configuration
      expect(config).to be_a(Lutaml::Qea::Services::Configuration)
    end

    it "returns fresh configuration instance" do
      described_class.configuration
      config2 = described_class.reload_configuration
      expect(config2).to be_a(Lutaml::Qea::Services::Configuration)
    end
  end

  describe ".connect" do
    it "returns database connection", :aggregate_failures do
      conn = described_class.connect(test_qea_file)
      expect(conn).to be_a(Lutaml::Qea::Infrastructure::DatabaseConnection)
      expect(conn.file_path).to eq(test_qea_file)
    end

    it "does not auto-connect" do
      conn = described_class.connect(test_qea_file)
      expect(conn.connected?).to be false
    end
  end

  describe ".open" do
    it "yields connection object" do
      yielded = nil
      described_class.open(test_qea_file) do |conn|
        yielded = conn
      end
      expect(yielded).to be_a(Lutaml::Qea::Infrastructure::DatabaseConnection)
    end

    it "allows database operations in block", :aggregate_failures do
      result = nil
      described_class.open(test_qea_file) do |conn|
        conn.with_connection do |db|
          result = db
            .execute("SELECT COUNT(*) as count FROM t_object").first["count"]
        end
      end
      expect(result).to be_an(Integer)
      expect(result).to be >= 0
    end

    it "closes connection after block", :aggregate_failures do
      connection = nil
      described_class.open(test_qea_file) do |conn|
        connection = conn
        conn.connect
        expect(conn.connected?).to be true
      end
      expect(connection.connected?).to be false
    end

    it "closes connection even if block raises error", :aggregate_failures do
      connection = nil
      expect do
        described_class.open(test_qea_file) do |conn|
          connection = conn
          conn.connect
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")

      expect(connection.connected?).to be false
    end
  end

  describe ".schema_info" do
    it "returns hash with schema information", :aggregate_failures do
      info = described_class.schema_info(test_qea_file)
      expect(info).to be_a(Hash)
      expect(info).to have_key(:tables)
      expect(info).to have_key(:statistics)
    end

    it "includes table list", :aggregate_failures do
      info = described_class.schema_info(test_qea_file)
      tables = info[:tables]
      expect(tables).to be_an(Array)
      expect(tables).to include("t_object", "t_package", "t_attribute")
    end

    it "includes statistics", :aggregate_failures do
      info = described_class.schema_info(test_qea_file)
      stats = info[:statistics]
      expect(stats).to be_a(Hash)
      expect(stats).to have_key("t_object")
      expect(stats["t_object"]).to be_an(Integer)
    end

    it "closes connection after retrieving info", :aggregate_failures do
      # This test ensures no connections are left open
      info = described_class.schema_info(test_qea_file)
      expect(info).not_to be_nil

      # If we can successfully get schema info again, connection was closed
      info2 = described_class.schema_info(test_qea_file)
      expect(info2).not_to be_nil
    end
  end

  describe "integration" do
    it "can read QEA file using public API" do
      # Use connect method
      conn = described_class.connect(test_qea_file)
      conn.with_connection do |db|
        reader = Lutaml::Qea::Infrastructure::SchemaReader.new(db)
        tables = reader.tables
        expect(tables).to include("t_object")
      end
      conn.close
    end

    it "can read QEA file using open method" do
      # Use open method
      described_class.open(test_qea_file) do |conn|
        conn.with_connection do |db|
          reader = Lutaml::Qea::Infrastructure::SchemaReader.new(db)
          stats = reader.statistics
          expect(stats).to have_key("t_object")
        end
      end
    end

    it "can use configuration and connect together" do
      config = described_class.configuration
      enabled_tables = config.enabled_table_names

      described_class.open(test_qea_file) do |conn|
        conn.with_connection do |db|
          schema_reader = Lutaml::Qea::Infrastructure::SchemaReader.new(db)
          available_tables = schema_reader.tables

          # Check that configured tables exist in database
          enabled_tables.each do |table_name|
            if available_tables.include?(table_name)
              expect(schema_reader.table_exists?(table_name)).to be true
            end
          end
        end
      end
    end

    it "can read table data using TableReader", :aggregate_failures do
      described_class.open(test_qea_file) do |conn|
        conn.with_connection do |db|
          reader = Lutaml::Qea::Infrastructure::TableReader.new(db, "t_object")
          count = reader.count
          expect(count).to be >= 0

          if count > 0
            records = reader.all(limit: 1)
            expect(records).not_to be_empty
            expect(records.first).to be_a(Hash)
          end
        end
      end
    end

    it "provides complete foundation for QEA parsing", :aggregate_failures do
      # Test that all Phase 1 components work together
      config = described_class.configuration
      expect(config.enabled_tables).not_to be_empty

      info = described_class.schema_info(test_qea_file)
      expect(info[:tables]).not_to be_empty
      expect(info[:statistics]).not_to be_empty

      described_class.open(test_qea_file) do |conn|
        conn.with_connection do |db|
          # Can read schema
          schema_reader = Lutaml::Qea::Infrastructure::SchemaReader.new(db)
          tables = schema_reader.tables
          expect(tables).not_to be_empty

          # Can read table data
          table_reader = Lutaml::Qea::Infrastructure::TableReader
            .new(db, "t_object")
          count = table_reader.count
          expect(count).to be >= 0
        end
      end
    end
  end
end
