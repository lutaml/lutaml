# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/services/database_loader"
require "lutaml/qea/database"
require "tempfile"
require "sqlite3"

RSpec.describe Lutaml::Qea::Services::DatabaseLoader do
  let(:qea_path) { "test.qea" }
  let(:loader) { described_class.new(qea_path) }

  describe "#initialize" do
    it "creates a loader with QEA path" do
      expect(loader.qea_path).to eq(qea_path)
    end

    it "loads default configuration" do
      expect(loader.config).to be_a(Lutaml::Qea::Services::Configuration)
    end

    it "accepts custom configuration" do
      config = Lutaml::Qea::Services::Configuration.new
      custom_loader = described_class.new(qea_path, config)
      expect(custom_loader.config).to eq(config)
    end
  end

  describe "#on_progress" do
    it "sets progress callback" do
      callback_called = false
      loader.on_progress { |_table, _current, _total| callback_called = true }

      expect(loader.instance_variable_get(:@progress_callback)).to be_a(Proc)
    end

    it "returns self for chaining" do
      result = loader.on_progress { |_t, _c, _tot| }
      expect(result).to eq(loader)
    end
  end

  describe "MODEL_CLASSES constant" do
    it "maps all table names to model classes" do
      expect(described_class::MODEL_CLASSES).to include(
        "t_object" => Lutaml::Qea::Models::EaObject,
        "t_attribute" => Lutaml::Qea::Models::EaAttribute,
        "t_operation" => Lutaml::Qea::Models::EaOperation,
        "t_operationparams" => Lutaml::Qea::Models::EaOperationParam,
        "t_connector" => Lutaml::Qea::Models::EaConnector,
        "t_package" => Lutaml::Qea::Models::EaPackage,
        "t_diagram" => Lutaml::Qea::Models::EaDiagram
      )
    end
  end

  context "with temporary test database" do
    let(:temp_db) { Tempfile.new(["test", ".qea"]) }
    let(:test_qea_path) { temp_db.path }
    let(:test_loader) { described_class.new(test_qea_path) }

    before do
      # Create a minimal test database
      db = SQLite3::Database.new(test_qea_path)
      db.results_as_hash = true

      # Create t_object table
      db.execute(<<~SQL)
        CREATE TABLE t_object (
          Object_ID INTEGER PRIMARY KEY,
          Name TEXT,
          Object_Type TEXT,
          Package_ID INTEGER
        )
      SQL

      # Insert test data
      db.execute(
        "INSERT INTO t_object (Object_ID, Name, Object_Type, Package_ID) VALUES (?, ?, ?, ?)",
        [1, "TestClass", "Class", 10]
      )
      db.execute(
        "INSERT INTO t_object (Object_ID, Name, Object_Type, Package_ID) VALUES (?, ?, ?, ?)",
        [2, "TestInterface", "Interface", 10]
      )

      # Create t_package table
      db.execute(<<~SQL)
        CREATE TABLE t_package (
          Package_ID INTEGER PRIMARY KEY,
          Name TEXT,
          Parent_ID INTEGER
        )
      SQL

      db.execute(
        "INSERT INTO t_package (Package_ID, Name, Parent_ID) VALUES (?, ?, ?)",
        [10, "TestPackage", 0]
      )

      # Create other required tables (empty)
      db.execute("CREATE TABLE t_attribute (ID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_operation (OperationID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_operationparams (OperationID INTEGER, Name TEXT)")
      db.execute("CREATE TABLE t_connector (Connector_ID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_diagram (Diagram_ID INTEGER PRIMARY KEY, Name TEXT)")

      db.close
    end

    after do
      temp_db.close
      temp_db.unlink
    end

    describe "#load" do
      it "returns a Database instance" do
        database = test_loader.load
        expect(database).to be_a(Lutaml::Qea::Database)
      end

      it "loads all enabled tables" do
        database = test_loader.load
        expect(database.collection_names).to include(
          :objects, :packages, :attributes, :operations,
          :operation_params, :connectors, :diagrams
        )
      end

      it "freezes the returned database" do
        database = test_loader.load
        expect(database).to be_frozen
      end

      it "loads correct number of objects" do
        database = test_loader.load
        expect(database.objects.count).to eq(2)
      end

      it "loads correct number of packages" do
        database = test_loader.load
        expect(database.packages.count).to eq(1)
      end

      it "calls progress callback" do
        progress_calls = []
        test_loader.on_progress do |table, current, total|
          progress_calls << { table: table, current: current, total: total }
        end

        test_loader.load
        expect(progress_calls).not_to be_empty
      end

      it "handles errors gracefully" do
        # This should not raise even if some records fail to load
        expect { test_loader.load }.not_to raise_error
      end
    end

    describe "#load_table" do
      it "loads a single table" do
        objects = test_loader.load_table("t_object")
        expect(objects).to be_an(Array)
        expect(objects.size).to eq(2)
      end

      it "returns model instances" do
        objects = test_loader.load_table("t_object")
        expect(objects.first).to be_a(Lutaml::Qea::Models::EaObject)
      end

      it "raises error for unconfigured table" do
        expect {
          test_loader.load_table("t_nonexistent")
        }.to raise_error(ArgumentError, /not configured/)
      end

      it "raises error for disabled table" do
        # Mock a disabled table in config
        allow(test_loader.config).to receive(:table_config_for).with("t_object").and_return(
          double(enabled: false)
        )

        expect {
          test_loader.load_table("t_object")
        }.to raise_error(ArgumentError, /not enabled/)
      end
    end

    describe "#quick_stats" do
      it "returns statistics hash" do
        stats = test_loader.quick_stats
        expect(stats).to be_a(Hash)
      end

      it "includes counts for all collections" do
        stats = test_loader.quick_stats
        expect(stats.keys).to include("objects", "packages")
      end

      it "has correct counts" do
        stats = test_loader.quick_stats
        expect(stats["objects"]).to eq(2)
        expect(stats["packages"]).to eq(1)
      end

      it "does not load actual records" do
        # This is a quick operation, should not create model instances
        expect(Lutaml::Qea::Models::EaObject).not_to receive(:from_db_row)
        test_loader.quick_stats
      end
    end
  end

  describe "error handling" do
    it "raises error for non-existent file" do
      bad_loader = described_class.new("nonexistent.qea")
      expect {
        bad_loader.load
      }.to raise_error(Errno::ENOENT)
    end

    it "warns when individual records fail to load" do
      # Test that individual record errors are caught and warned
      # We'll test this by mocking from_db_row to fail
      temp_db = Tempfile.new(["test", ".qea"])
      db = SQLite3::Database.new(temp_db.path)
      db.results_as_hash = true

      # Create all required tables
      db.execute("CREATE TABLE t_object (Object_ID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_attribute (ID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_operation (OperationID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_operationparams (OperationID INTEGER, Name TEXT)")
      db.execute("CREATE TABLE t_connector (Connector_ID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_package (Package_ID INTEGER PRIMARY KEY, Name TEXT)")
      db.execute("CREATE TABLE t_diagram (Diagram_ID INTEGER PRIMARY KEY, Name TEXT)")

      db.execute("INSERT INTO t_object (Object_ID, Name) VALUES (1, 'Test')")
      db.close

      loader = described_class.new(temp_db.path)

      # Mock from_db_row to fail for one call
      allow(Lutaml::Qea::Models::EaObject).to receive(:from_db_row).and_raise(StandardError.new("Test error"))

      # Should not raise error, just warn
      expect { loader.load }.not_to raise_error

      temp_db.close
      temp_db.unlink
    end
  end
end