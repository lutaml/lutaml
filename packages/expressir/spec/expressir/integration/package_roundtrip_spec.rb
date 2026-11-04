# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "LER Package Round-trip Integration", :integration do
  let(:test_schema_content) do
    <<~EXPRESS
      SCHEMA test_schema;
        ENTITY test_entity;
          name : STRING;
        END_ENTITY;

        TYPE test_select = SELECT (test_entity);
        END_TYPE;
      END_SCHEMA;
    EXPRESS
  end

  let(:dependency_schema_content) do
    <<~EXPRESS
      SCHEMA dependency_schema;
        ENTITY dependency_entity;
          id : STRING;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  let(:schema_with_interface_content) do
    <<~EXPRESS
      SCHEMA main_schema;
        USE FROM dependency_schema(dependency_entity);

        ENTITY main_entity;
          dep_ref : dependency_entity;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  describe "single schema round-trip" do
    it "creates package, loads it, and queries work correctly" do
      Dir.mktmpdir do |dir|
        # Step 1: Create schema file
        schema_file = File.join(dir, "test_schema.exp")
        File.write(schema_file, test_schema_content)

        # Step 2: Parse and build repository
        repo = Expressir::Model::Repository.new
        parsed = Expressir::Express::Parser.from_file(schema_file)
        parsed.schemas.each { |schema| repo.add_schema(schema) }
        repo.resolve_all_references

        expect(repo.schemas.size).to eq(1)
        expect(repo.schemas.first.id).to eq("test_schema")

        # Step 3: Export to package
        package_path = File.join(dir, "test.ler")
        repo.export_to_package(
          package_path,
          name: "Test Package",
          version: "1.0.0",
          express_mode: "include_all",
          resolution_mode: "resolved",
          serialization_format: "yaml",
        )

        expect(File.exist?(package_path)).to be true

        # Step 4: Load package
        loaded_repo = Expressir::Model::Repository.from_package(package_path)

        # Step 5: Verify loaded repository
        expect(loaded_repo.entity_index).not_to be_nil
        expect(loaded_repo.type_index).not_to be_nil
        expect(loaded_repo.reference_index).not_to be_nil

        # Step 6: Query entities
        entity = loaded_repo.find_entity(qualified_name: "test_schema.test_entity")
        expect(entity).not_to be_nil
        expect(entity.id).to eq("test_entity")

        # Step 7: Query types
        type = loaded_repo.find_type(qualified_name: "test_schema.test_select")
        expect(type).not_to be_nil
        expect(type.id).to eq("test_select")

        # Step 8: List entities
        entities = loaded_repo.list_entities(format: :hash)
        expect(entities.size).to eq(1)
        expect(entities.first[:id]).to eq("test_entity")

        # Step 9: Verify manifest paths are package-internal
        require "zip"
        Zip::File.open(package_path) do |zip|
          manifest_entry = zip.find_entry("manifest.yaml")
          manifest_content = manifest_entry.get_input_stream.read
          manifest = Expressir::SchemaManifest.from_yaml(manifest_content)

          expect(manifest.schemas.size).to eq(1)
          expect(manifest.schemas.first.path).to eq("express_files/test_schema.exp")
          expect(manifest.schemas.first.path).not_to include(dir) # No absolute paths
        end

        # Windows: Ensure zip files are released before cleanup
        GC.start if Gem.win_platform?
      end
    end
  end

  describe "multi-schema with dependencies round-trip" do
    it "resolves dependencies and creates queryable package" do
      Dir.mktmpdir do |dir|
        # Step 1: Create schema files
        dep_file = File.join(dir, "dependency_schema.exp")
        main_file = File.join(dir, "main_schema.exp")
        File.write(dep_file, dependency_schema_content)
        File.write(main_file, schema_with_interface_content)

        # Step 2: Use DependencyResolver
        resolver = Expressir::Model::DependencyResolver.new(base_dirs: [dir])
        schema_files = resolver.resolve_dependencies(main_file)

        expect(schema_files.size).to eq(2)
        expect(schema_files).to include(main_file)
        expect(schema_files).to include(dep_file)

        # Step 3: Build repository from files
        repo = Expressir::Model::Repository.from_files(schema_files)

        expect(repo.schemas.size).to eq(2)

        # Step 4: Export to package
        package_path = File.join(dir, "multi.ler")
        repo.export_to_package(
          package_path,
          name: "Multi Schema Package",
          version: "2.0.0",
          express_mode: "include_all",
          resolution_mode: "resolved",
          serialization_format: "yaml",
        )

        # Step 5: Load and verify
        loaded_repo = Expressir::Model::Repository.from_package(package_path)

        # Step 6: Verify both schemas are queryable
        main_entity = loaded_repo.find_entity(qualified_name: "main_schema.main_entity")
        dep_entity = loaded_repo.find_entity(qualified_name: "dependency_schema.dependency_entity")

        expect(main_entity).not_to be_nil
        expect(dep_entity).not_to be_nil

        # Step 7: Verify manifest has correct package-internal paths
        require "zip"
        Zip::File.open(package_path) do |zip|
          manifest_entry = zip.find_entry("manifest.yaml")
          manifest = Expressir::SchemaManifest.from_yaml(manifest_entry.get_input_stream.read)

          expect(manifest.schemas.size).to eq(2)
          manifest.schemas.each do |schema_entry|
            expect(schema_entry.path).to start_with("express_files/")
            expect(schema_entry.path).to end_with(".exp")
            # Path should be express_files/schema_name.exp (contains one /)
            expect(schema_entry.path).to match(/^express_files\/\w+\.exp$/)
          end
        end

        # Step 8: Verify EXPRESS files exist in package
        Zip::File.open(package_path) do |zip|
          expect(zip.find_entry("express_files/main_schema.exp")).not_to be_nil
          expect(zip.find_entry("express_files/dependency_schema.exp")).not_to be_nil
        end

        # Windows: Ensure zip files are released before cleanup
        GC.start if Gem.win_platform?
      end
    end
  end

  describe "package with different serialization formats" do
    ["yaml", "json"].each do |format|
      it "round-trips correctly with #{format} format" do
        Dir.mktmpdir do |dir|
          # Create simple schema
          schema_file = File.join(dir, "simple.exp")
          File.write(schema_file, test_schema_content)

          # Build repository
          repo = Expressir::Model::Repository.new
          parsed = Expressir::Express::Parser.from_file(schema_file)
          parsed.schemas.each { |schema| repo.add_schema(schema) }

          # Export with specific format
          package_path = File.join(dir, "test_#{format}.ler")
          repo.export_to_package(
            package_path,
            serialization_format: format,
            resolution_mode: "resolved",
          )

          # Load and verify
          loaded_repo = Expressir::Model::Repository.from_package(package_path)
          entity = loaded_repo.find_entity(qualified_name: "test_schema.test_entity")

          expect(entity).not_to be_nil
          expect(entity.id).to eq("test_entity")

          # Windows: Ensure zip files are released before cleanup
          GC.start if Gem.win_platform?
        end
      end
    end
  end

  describe "package statistics accuracy" do
    it "reports correct statistics after loading" do
      Dir.mktmpdir do |dir|
        schema_file = File.join(dir, "stats_test.exp")
        File.write(schema_file, test_schema_content)

        repo = Expressir::Model::Repository.new
        parsed = Expressir::Express::Parser.from_file(schema_file)
        parsed.schemas.each { |schema| repo.add_schema(schema) }

        original_stats = repo.statistics

        # Package and reload
        package_path = File.join(dir, "stats.ler")
        repo.export_to_package(package_path, serialization_format: "yaml")

        loaded_repo = Expressir::Model::Repository.from_package(package_path)
        loaded_stats = loaded_repo.statistics

        # Compare statistics
        # Note: Statistics count from indexes, not schemas collection
        # so they should match even if schemas collection is empty
        expect(loaded_stats[:total_entities]).to eq(original_stats[:total_entities])
        expect(loaded_stats[:total_types]).to eq(original_stats[:total_types])

        # Verify indexes are working
        expect(loaded_repo.entity_index.count).to eq(1)
        expect(loaded_repo.type_index.count).to eq(1)

        # Windows: Ensure zip files are released before cleanup
        GC.start if Gem.win_platform?
      end
    end
  end

  describe "CLI integration" do
    it "builds package via CLI and queries work" do
      Dir.mktmpdir do |dir|
        # Create test schema
        schema_file = File.join(dir, "cli_test.exp")
        File.write(schema_file, test_schema_content)

        package_path = File.join(dir, "cli_built.ler")

        # Build via Repository.from_files (simulating CLI)
        schema_files = [schema_file]
        repo = Expressir::Model::Repository.from_files(schema_files)
        repo.export_to_package(
          package_path,
          name: "CLI Test",
          version: "1.0.0",
          serialization_format: "yaml",
        )

        # Verify package exists
        expect(File.exist?(package_path)).to be true

        # Load and query
        loaded_repo = Expressir::Model::Repository.from_package(package_path)
        entity = loaded_repo.find_entity(qualified_name: "test_schema.test_entity")

        expect(entity).not_to be_nil

        # Windows: Ensure zip files are released before cleanup
        GC.start if Gem.win_platform?
      end
    end
  end

  describe "index preservation" do
    it "preserves indexes across package round-trip" do
      Dir.mktmpdir do |dir|
        schema_file = File.join(dir, "index_test.exp")
        File.write(schema_file, test_schema_content)

        # Build original repository
        repo = Expressir::Model::Repository.new
        parsed = Expressir::Express::Parser.from_file(schema_file)
        parsed.schemas.each { |schema| repo.add_schema(schema) }
        repo.build_indexes

        original_entity_count = repo.entity_index.count
        original_type_count = repo.type_index.count

        # Package and reload
        package_path = File.join(dir, "index.ler")
        repo.export_to_package(package_path, serialization_format: "yaml")

        loaded_repo = Expressir::Model::Repository.from_package(package_path)

        # Verify indexes were preserved
        expect(loaded_repo.entity_index.count).to eq(original_entity_count)
        expect(loaded_repo.type_index.count).to eq(original_type_count)
        expect(loaded_repo.entity_index.empty?).to be false
        expect(loaded_repo.type_index.empty?).to be false

        # Windows: Ensure zip files are released before cleanup
        GC.start if Gem.win_platform?
      end
    end
  end
end
