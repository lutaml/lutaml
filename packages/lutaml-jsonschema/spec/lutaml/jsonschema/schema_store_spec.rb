# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe Lutaml::Jsonschema::SchemaStore do
  let(:tmpdir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(tmpdir) }

  def create_test_schema_dir(dir)
    FileUtils.mkdir_p(dir)
    src_dir = fixture_path(".")
    Dir.glob(File.join(src_dir, "*.json")).each do |path|
      FileUtils.cp(path, File.join(dir, File.basename(path)))
    end
    dir
  end

  # ── Construction ──

  describe ".new" do
    it "creates an empty store" do
      store = described_class.new
      expect(store.schema_count).to eq(0)
      expect(store.schemas).to eq({})
    end

    it "creates an empty store with a default package" do
      store = described_class.new
      expect(store.package).to be_a(Lutaml::Store::PackageStore)
    end
  end

  # ── load_from_files ──

  describe ".load_from_files" do
    it "loads schemas from explicit file paths" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      expect(store.schema_count).to be > 0
    end

    it "sets dollar_id from filename when missing" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      store.schemas.each_value do |schema|
        expect(schema.dollar_id).not_to be_nil
      end
    end

    it "populates the package store" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      expect(store.package.model_count(Lutaml::Jsonschema::Schema)).to be > 0
    end

    it "preserves file path in SchemaSet" do
      path = fixture_path("person.json")
      store = described_class.load_from_files(path)
      schema = store.schema("person")
      expect(schema).to be_a(Lutaml::Jsonschema::Schema)
      expect(schema.dollar_id).to eq("https://example.com/person.schema.json")
    end
  end

  # ── load_from_directory ──

  describe ".load_from_directory" do
    it "loads all JSON schemas from directory" do
      dir = create_test_schema_dir(File.join(tmpdir, "schemas"))
      store = described_class.load_from_directory(dir)
      expect(store.schema_count).to be > 0
    end

    it "handles missing configuration file" do
      dir = create_test_schema_dir(File.join(tmpdir, "schemas"))
      store = described_class.load_from_directory(dir)
      expect(store.configuration).to be_nil
    end
  end

  # ── add_schema / remove_schema ──

  describe "#add_schema" do
    let(:store) { described_class.new }

    it "adds a schema to both schemas hash and package" do
      schema = Lutaml::Jsonschema::Schema.new(dollar_id: "test-schema",
                                              title: "Test")
      store.add_schema(schema)
      expect(store.schema_exists?("test-schema")).to be true
      expect(store.schema("test-schema").title).to eq("Test")
      expect(store.package.model_exists?(Lutaml::Jsonschema::Schema,
                                         "test-schema")).to be true
    end

    it "derives name from file_path when dollar_id is nil" do
      schema = Lutaml::Jsonschema::Schema.new(title: "No ID")
      store.add_schema(schema, "/path/to/my_schema.json")
      expect(store.schema_exists?("my_schema")).to be true
    end

    it "raises when both dollar_id and file_path are nil" do
      schema = Lutaml::Jsonschema::Schema.new(title: "No ID")
      expect { store.add_schema(schema) }
        .to raise_error(Lutaml::Jsonschema::Error,
                        /must have \$id or file_path/)
    end
  end

  describe "#remove_schema" do
    let(:store) { described_class.new }

    it "removes a schema from both schemas hash and package" do
      schema = Lutaml::Jsonschema::Schema.new(dollar_id: "test-schema")
      store.add_schema(schema)
      store.remove_schema("test-schema")
      expect(store.schema_exists?("test-schema")).to be false
      expect(store.package.model_exists?(Lutaml::Jsonschema::Schema,
                                         "test-schema")).to be false
    end

    it "does not raise when removing non-existent schema" do
      store.remove_schema("nope")
      expect(store.schema_exists?("nope")).to be false
    end
  end

  # ── Convenience accessors ──

  describe "#schema / #schema_names / #schema_count" do
    let(:store) { described_class.new }

    it "returns schema by name" do
      schema = Lutaml::Jsonschema::Schema.new(dollar_id: "a", title: "A")
      store.add_schema(schema)
      expect(store.schema("a")).to eq(schema)
    end

    it "returns nil for unknown schema" do
      expect(store.schema("missing")).to be_nil
    end

    it "returns all schema names" do
      %w[a b c].each { |n| store.add_schema(Lutaml::Jsonschema::Schema.new(dollar_id: n)) }
      expect(store.schema_names).to contain_exactly("a", "b", "c")
    end

    it "returns correct count" do
      3.times { |i| store.add_schema(Lutaml::Jsonschema::Schema.new(dollar_id: "s#{i}")) }
      expect(store.schema_count).to eq(3)
    end
  end

  # ── Inherited from SchemaSet ──

  describe "ref resolution (inherited from SchemaSet)" do
    it "resolves local refs" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      schema = store.schemas.values.first
      resolved = store.resolve_ref("#/definitions/nonexistent", schema)
      expect(resolved).to be_nil
    end
  end

  describe "validation (inherited from SchemaSet)" do
    it "validates loaded schemas" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      expect(store.valid?).to be true
    end

    it "returns validation errors via SchemaSet method" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      expect(store.validation_errors).to be_a(Array)
    end
  end

  describe "all_definitions / all_properties (inherited from SchemaSet)" do
    it "delegates to SchemaSet" do
      paths = Dir.glob(fixture_path("*.json"))
      store = described_class.load_from_files(*paths)
      expect(store.all_definitions).to be_a(Array)
      expect(store.all_properties).to be_a(Array)
    end
  end

  # ── Configuration ──

  describe "#configuration / #configuration=" do
    let(:store) { described_class.new }

    it "returns nil when no configuration set" do
      expect(store.configuration).to be_nil
    end

    it "stores and retrieves configuration" do
      config = Lutaml::Jsonschema::Configuration.new(title: "My API",
                                                     version: "1.0")
      store.configuration = config
      expect(store.configuration.title).to eq("My API")
      expect(store.configuration.version).to eq("1.0")
    end

    it "replaces existing configuration" do
      store.configuration = Lutaml::Jsonschema::Configuration.new(title: "v1")
      store.configuration = Lutaml::Jsonschema::Configuration.new(title: "v2")
      expect(store.configuration.title).to eq("v2")
    end
  end

  # ── save_to_directory ──

  describe "#save_to_directory" do
    it "writes schemas as JSON files" do
      dir = create_test_schema_dir(File.join(tmpdir, "schemas"))
      store = described_class.load_from_directory(dir)

      output = File.join(tmpdir, "output")
      store.save_to_directory(output)

      files = Dir.glob(File.join(output, "*.json"))
      expect(files.length).to eq(store.schema_count)
    end
  end

  # ── Round-trip ──

  describe "load → save → load round-trip" do
    it "preserves schemas" do
      dir = create_test_schema_dir(File.join(tmpdir, "schemas"))
      store = described_class.load_from_directory(dir)
      count = store.schema_count

      output = File.join(tmpdir, "roundtrip")
      store.save_to_directory(output)

      reloaded = described_class.load_from_directory(output)
      expect(reloaded.schema_count).to eq(count)
    end
  end

  # ── Edge cases ──

  describe "edge cases" do
    it "handles duplicate dollar_id by overwriting" do
      store = described_class.new
      store.add_schema(Lutaml::Jsonschema::Schema.new(dollar_id: "dup",
                                                      title: "First"))
      store.add_schema(Lutaml::Jsonschema::Schema.new(dollar_id: "dup",
                                                      title: "Second"))
      expect(store.schema("dup").title).to eq("Second")
    end

    it "handles empty store validation" do
      store = described_class.new
      expect(store.valid?).to be true
    end
  end
end
