# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/infrastructure/database_connection"
require "tempfile"
require "sqlite3"

RSpec.describe Lutaml::Qea::Infrastructure::DatabaseConnection do
  let(:test_qea_file) do
    File.expand_path("../../../../examples/qea/test.qea", __dir__)
  end
  let(:nonexistent_file) { "nonexistent.qea" }

  describe "#initialize" do
    it "creates a new connection instance" do
      conn = described_class.new(test_qea_file)
      expect(conn).to be_a(described_class)
      expect(conn.file_path).to eq(test_qea_file)
    end

    it "raises ArgumentError when file_path is nil" do
      expect do
        described_class.new(nil)
      end.to raise_error(ArgumentError,
                         /cannot be nil or empty/)
    end

    it "raises ArgumentError when file_path is empty" do
      expect do
        described_class.new("")
      end.to raise_error(ArgumentError,
                         /cannot be nil or empty/)
    end
  end

  describe "#connect" do
    let(:connection) { described_class.new(test_qea_file) }

    after do
      connection.close if connection.connected?
    end

    it "opens a connection to the database" do
      db = connection.connect
      expect(db).to be_a(SQLite3::Database)
      expect(connection.connected?).to be true
    end

    it "sets results_as_hash to true" do
      connection.connect
      result = connection.connection.execute("SELECT 1 as test").first
      expect(result).to be_a(Hash)
      expect(result["test"]).to eq(1)
    end

    it "opens database in readonly mode" do
      connection.connect
      expect do
        connection.connection.execute("CREATE TABLE test_table (id INTEGER)")
      end.to raise_error(SQLite3::ReadOnlyException)
    end

    it "raises error when file does not exist" do
      conn = described_class.new(nonexistent_file)
      expect do
        conn.connect
      end.to raise_error(Errno::ENOENT, /QEA file not found/)
    end
  end

  describe "#close" do
    let(:connection) { described_class.new(test_qea_file) }

    it "closes an open connection" do
      connection.connect
      expect(connection.connected?).to be true

      connection.close
      expect(connection.connected?).to be false
      expect(connection.connection).to be_nil
    end

    it "does nothing when connection is not open" do
      expect { connection.close }.not_to raise_error
    end
  end

  describe "#connected?" do
    let(:connection) { described_class.new(test_qea_file) }

    after do
      connection.close if connection.connected?
    end

    it "returns false when not connected" do
      expect(connection.connected?).to be false
    end

    it "returns true when connected" do
      connection.connect
      expect(connection.connected?).to be true
    end

    it "returns false after closing connection" do
      connection.connect
      connection.close
      expect(connection.connected?).to be false
    end
  end

  describe "#with_connection" do
    let(:connection) { described_class.new(test_qea_file) }

    it "yields a database connection" do
      result = nil
      connection.with_connection do |db|
        result = db
      end
      expect(result).to be_a(SQLite3::Database)
    end

    it "automatically opens and closes connection" do
      expect(connection.connected?).to be false

      connection.with_connection do |db|
        expect(db).to be_a(SQLite3::Database)
        expect(connection.connected?).to be true
      end

      expect(connection.connected?).to be false
    end

    it "reuses existing connection" do
      connection.connect
      original_conn = connection.connection

      connection.with_connection do |db|
        expect(db).to eq(original_conn)
      end

      expect(connection.connected?).to be true
      connection.close
    end

    it "returns block result" do
      result = connection.with_connection do |db|
        db.execute("SELECT COUNT(*) as count FROM t_object").first["count"]
      end
      expect(result).to be_a(Integer)
    end

    it "allows database queries" do
      connection.with_connection do |db|
        tables = db.execute(
          "SELECT name FROM sqlite_master WHERE type='table' " \
          "AND name='t_object'",
        )
        expect(tables).not_to be_empty
        expect(tables.first["name"]).to eq("t_object")
      end
    end

    it "closes connection even if block raises error" do
      expect do
        connection.with_connection do |_db|
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")

      expect(connection.connected?).to be false
    end

    it "does not close pre-existing connection on error" do
      connection.connect

      expect do
        connection.with_connection do |_db|
          raise StandardError, "test error"
        end
      end.to raise_error(StandardError, "test error")

      expect(connection.connected?).to be true
      connection.close
    end
  end

  describe "integration" do
    it "can read actual QEA file data" do
      conn = described_class.new(test_qea_file)
      conn.with_connection do |db|
        # Verify we can read tables
        tables = db.execute(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        ).map { |row| row["name"] }

        expect(tables).to include("t_object", "t_package", "t_attribute")

        # Verify we can count records
        count = db.execute("SELECT COUNT(*) as count FROM t_object")
          .first["count"]
        expect(count).to be >= 0
      end
    end
  end
end
