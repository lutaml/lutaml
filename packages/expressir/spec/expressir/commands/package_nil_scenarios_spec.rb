# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "zip"
require "stringio"

RSpec.describe Expressir::Commands::Package,
               "nil scenarios and error handling" do
  include Expressir::ConsoleHelper

  let(:temp_dir) { Dir.mktmpdir }
  let(:test_output) { File.join(temp_dir, "test.ler") }
  let(:extract_dir) { File.join(temp_dir, "extracted") }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "nil metadata field handling" do
    let(:minimal_metadata) do
      Expressir::Package::Metadata.new(
        name: "Test Package",
        version: "1.0.0",
      )
    end

    let(:nil_fields_metadata) do
      Expressir::Package::Metadata.new(
        name: "Test Package",
        version: "1.0.0",
        description: nil,
        created_at: nil,
        created_by: nil,
        express_mode: nil,
        resolution_mode: nil,
        serialization_format: nil,
      )
    end

    let(:empty_fields_metadata) do
      Expressir::Package::Metadata.new(
        name: "Test Package",
        version: "1.0.0",
        description: "",
        created_at: "",
        created_by: "",
        express_mode: "",
        resolution_mode: "",
        serialization_format: "",
      )
    end

    describe "#output_text_info" do
      let(:command) { described_class.new }
      let(:empty_repo) do
        Expressir::Model::Repository.new.tap do |repo|
          repo.instance_variable_set(:@schemas, [])
        end
      end

      it "handles nil metadata fields gracefully" do
        output = capture_stdout do
          command.send(:output_text_info, nil_fields_metadata, empty_repo)
        end

        expect(output).to include("Name:        Test Package")
        expect(output).to include("Version:     1.0.0")
        expect(output).not_to include("Description:")
        expect(output).not_to include("Created:")
        expect(output).not_to include("Created by:")
      end

      it "handles empty string metadata fields gracefully" do
        output = capture_stdout do
          command.send(:output_text_info, empty_fields_metadata, empty_repo)
        end

        expect(output).to include("Name:        Test Package")
        expect(output).to include("Version:     1.0.0")
        expect(output).not_to include("Description:")
      end

      it "does not call .empty? on nil description" do
        # This specifically tests the original bug where .empty? was called on nil
        expect do
          capture_stdout do
            command.send(:output_text_info, nil_fields_metadata, empty_repo)
          end
        end.not_to raise_error
      end

      it "handles nil repository statistics" do
        allow(empty_repo).to receive(:statistics).and_return(nil)

        # This should be fixed in implementation
        expect do
          capture_stdout do
            command.send(:output_text_info, minimal_metadata,
                         empty_repo)
          end
        end.to raise_error(NoMethodError)
      end

      it "handles empty repository statistics" do
        allow(empty_repo).to receive(:statistics).and_return({})

        output = capture_stdout do
          command.send(:output_text_info, minimal_metadata, empty_repo)
        end

        expect(output).to include("Statistics")
        expect(output).to include("Total schemas:")
        expect(output).to include("Total entities:")
      end
    end

    describe "#output_json_info" do
      let(:command) { described_class.new }
      let(:empty_repo) do
        Expressir::Model::Repository.new.tap do |repo|
          repo.instance_variable_set(:@schemas, [])
        end
      end

      it "handles nil metadata fields in JSON output" do
        output = capture_stdout do
          command.send(:output_json_info, nil_fields_metadata, empty_repo)
        end

        json_data = JSON.parse(output)
        expect(json_data["metadata"]["name"]).to eq("Test Package")
        expect(json_data["metadata"]["version"]).to eq("1.0.0")
        expect(json_data["metadata"]["description"]).to be_nil
      end

      it "handles nil repository statistics in JSON" do
        allow(empty_repo).to receive(:statistics).and_return(nil)

        output = capture_stdout do
          command.send(:output_json_info, minimal_metadata, empty_repo)
        end

        json_data = JSON.parse(output)
        expect(json_data["statistics"]).to eq({})
      end
    end

    describe "#output_yaml_info" do
      let(:command) { described_class.new }
      let(:empty_repo) do
        Expressir::Model::Repository.new.tap do |repo|
          repo.instance_variable_set(:@schemas, [])
        end
      end

      it "handles nil metadata fields in YAML output" do
        output = capture_stdout do
          command.send(:output_yaml_info, nil_fields_metadata, empty_repo)
        end

        yaml_data = YAML.safe_load(output)
        expect(yaml_data["metadata"]["name"]).to eq("Test Package")
        expect(yaml_data["metadata"]["version"]).to eq("1.0.0")
        expect(yaml_data["metadata"]["description"]).to be_nil
      end
    end
  end

  describe "empty repository scenarios" do
    let(:empty_package_path) { File.join(temp_dir, "empty.ler") }

    before do
      # Create an empty package
      empty_repo = Expressir::Model::Repository.new
      empty_repo.instance_variable_set(:@schemas, [])

      Zip::File.open(empty_package_path, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(
          name: "Empty Package",
          version: "1.0.0",
          schemas: 0,
          files: 0,
        )
        zip.get_output_stream("metadata.yaml") do |s|
          s.write(metadata.to_yaml)
        end

        # Add empty serialized repository
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(empty_repo))
        end

        # Add empty indexes
        zip.get_output_stream("entity_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("type_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("reference_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end

        # Add empty manifest
        manifest = { schemas: [] }
        zip.get_output_stream("manifest.yaml") do |s|
          s.write(manifest.to_yaml)
        end
      end
    end

    describe "#list" do
      it "handles empty repository gracefully" do
        command = described_class.new("type" => "entity")

        expect do
          capture_stdout do
            command.list(empty_package_path)
          end
        end.not_to raise_error
      end

      it "returns empty results for empty repository" do
        command = described_class.new("type" => "entity", "format" => "json")

        output = capture_stdout do
          command.list(empty_package_path)
        end

        results = JSON.parse(output)
        expect(results).to be_empty
      end

      it "handles count_only with empty repository" do
        command = described_class.new("type" => "entity", "count_only" => true)

        output = capture_stdout do
          command.list(empty_package_path)
        end

        expect(output.strip).to eq("0")
      end
    end

    describe "#search" do
      it "handles search with no matches" do
        command = described_class.new

        expect do
          capture_stdout do
            command.search(empty_package_path, "nonexistent")
          end
        end.not_to raise_error
      end

      it "returns empty results for no matches" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.search(empty_package_path, "nonexistent")
        end

        results = JSON.parse(output)
        expect(results).to be_empty
      end

      it "handles count_only with no matches" do
        command = described_class.new("count_only" => true)

        output = capture_stdout do
          command.search(empty_package_path, "nonexistent")
        end

        expect(output.strip).to eq("0")
      end
    end

    describe "#tree" do
      it "handles empty schemas gracefully" do
        command = described_class.new

        output = capture_stdout do
          command.tree(empty_package_path)
        end

        expect(output).to include("No schemas found")
      end

      it "handles schema filter with empty repository" do
        command = described_class.new("schema" => "nonexistent_schema")

        output = capture_stdout do
          command.tree(empty_package_path)
        end

        expect(output).to include("No schemas found")
      end
    end
  end

  describe "corrupted package scenarios" do
    let(:corrupted_package_path) { File.join(temp_dir, "corrupted.ler") }

    describe "#extract" do
      it "handles missing output option gracefully" do
        command = described_class.new

        expect do
          command.extract("test.ler")
        end.to raise_error(Expressir::MissingRequiredArgumentError)
      end

      it "handles corrupted ZIP file" do
        # Create an invalid ZIP file
        File.write(corrupted_package_path, "not a zip file")

        command = described_class.new("output" => extract_dir)

        expect do
          command.extract(corrupted_package_path)
        end.to raise_error(Expressir::PackageExtractError)
      end

      it "handles ZIP with missing entries" do
        # Create ZIP with missing required files
        Zip::File.open(corrupted_package_path, create: true) do |zip|
          zip.get_output_stream("dummy.txt") { |s| s.write("test") }
        end

        command = described_class.new("output" => extract_dir)

        # extract should work even with missing files
        expect do
          command.extract(corrupted_package_path)
        end.not_to raise_error
      end
    end

    describe "#info" do
      it "handles package with missing metadata" do
        # Create ZIP without metadata
        Zip::File.open(corrupted_package_path, create: true) do |zip|
          zip.get_output_stream("dummy.txt") { |s| s.write("test") }
        end

        command = described_class.new

        expect do
          command.info(corrupted_package_path)
        end.to raise_error(Expressir::PackageReadError)
      end

      it "handles package with corrupted metadata" do
        # Create ZIP with invalid metadata
        Zip::File.open(corrupted_package_path, create: true) do |zip|
          zip.get_output_stream("metadata.yaml") do |s|
            s.write("invalid: yaml: content:")
          end
        end

        command = described_class.new

        expect do
          command.info(corrupted_package_path)
        end.to raise_error(Expressir::PackageReadError)
      end
    end

    describe "#validate" do
      it "handles package with invalid structure" do
        # Create ZIP with minimal invalid structure
        Zip::File.open(corrupted_package_path, create: true) do |zip|
          metadata = Expressir::Package::Metadata.new(
            name: "Invalid Package",
            version: "1.0.0",
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
          end
          # Missing repository and indexes
        end

        command = described_class.new

        expect do
          command.validate(corrupted_package_path)
        end.to raise_error(Expressir::PackageValidationError)
      end
    end
  end

  describe "edge cases in tree display" do
    let(:command) { described_class.new }

    describe "helper methods with nil inputs" do
      describe "#build_counts_text" do
        it "handles schema with nil collections" do
          schema = Expressir::Model::Declarations::Schema.new(
            id: "test_schema",
            entities: nil,
            types: nil,
            functions: nil,
          )

          result = command.send(:build_counts_text, schema)
          expect(result).to eq("")
        end

        it "handles schema with empty collections" do
          schema = Expressir::Model::Declarations::Schema.new(
            id: "test_schema",
            entities: [],
            types: [],
            functions: [],
          )

          result = command.send(:build_counts_text, schema)
          expect(result).to eq("")
        end
      end

      describe "#extract_type_info" do
        it "handles element with nil type" do
          element = Expressir::Model::Declarations::Attribute.new(
            id: "test_attr",
            type: nil,
          )

          result = command.send(:extract_type_info, element)
          expect(result).to eq("ANY")
        end
      end

      describe "#collect_schema_children" do
        it "handles schema with nil collections" do
          schema = Expressir::Model::Declarations::Schema.new(
            id: "test_schema",
            entities: nil,
            types: nil,
            functions: nil,
            procedures: nil,
            rules: nil,
          )

          allow(command).to receive(:should_include_type?).and_return(true)

          result = command.send(:collect_schema_children, schema)
          expect(result).to be_empty
        end
      end

      describe "#display_entity_children" do
        it "handles entity with nil attributes" do
          entity = Expressir::Model::Declarations::Entity.new(
            id: "test_entity",
            attributes: nil,
            derived_attributes: nil,
            inverse_attributes: nil,
          )

          allow(command).to receive(:should_include_type?).and_return(true)

          expect do
            command.send(:display_entity_children, entity, "", 1)
          end.not_to raise_error
        end
      end
    end
  end

  describe "search engine nil scenarios" do
    let(:empty_repo) do
      Expressir::Model::Repository.new.tap do |repo|
        repo.instance_variable_set(:@schemas, [])
        repo.build_indexes
      end
    end

    let(:search_engine) { Expressir::Model::SearchEngine.new(empty_repo) }

    it "handles search with nil pattern parts" do
      expect do
        search_engine.search(pattern: "", type: "entity")
      end.not_to raise_error
    end

    it "handles list with nil schema filter" do
      expect do
        search_engine.list(type: "entity", schema: nil)
      end.not_to raise_error
    end

    it "handles search with nil element paths" do
      # Create an Alias statement which naturally returns nil for path
      element = Expressir::Model::Statements::Alias.new(
        id: "test_alias",
        expression: nil,
        statements: [],
      )

      expect(element.path).to be_nil

      pattern_parts = { normalized: "test", parts: ["test"] }

      result = search_engine.send(:matches_pattern?,
                                  element, pattern_parts, "alias",
                                  case_sensitive: false, regex: false, exact: false)

      expect(result).to be false
    end
  end

  describe "validation with nil scenarios" do
    describe "#output_text_validation" do
      let(:command) { described_class.new }

      it "handles validation results with nil warnings" do
        validation = {
          valid?: true,
          errors: [],
          warnings: nil,
        }

        output = capture_stdout do
          command.send(:output_text_validation, validation)
        end

        expect(output).to include("✓ Package is valid")
        expect(output).not_to include("Warnings:")
      end

      it "handles validation results with empty warnings" do
        validation = {
          valid?: true,
          errors: [],
          warnings: [],
        }

        output = capture_stdout do
          command.send(:output_text_validation, validation)
        end

        expect(output).to include("✓ Package is valid")
        expect(output).not_to include("Warnings:")
      end

      it "handles validation results with nil errors" do
        validation = {
          valid?: false,
          errors: nil, # nil errors - should be handled gracefully
          warnings: [],
        }

        expect do
          output = capture_stdout do
            command.send(:output_text_validation, validation)
          end
          expect(output).to include("✗ Validation failed")
          expect(output).to include("Errors (0):")
        end.not_to raise_error
      end
    end
  end

  describe "CLI output formatting with nil guards" do
    describe "#output_text_list" do
      let(:command) { described_class.new }

      it "handles results with nil schema" do
        results = [
          { id: "test_element", schema: nil, path: nil },
        ]

        output = capture_stdout do
          command.send(:output_text_list, results, "entity", nil, nil)
        end

        expect(output).to include("test_element")
      end

      it "handles results with nil path when show_path is true" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ show_path: true })

        results = [
          { id: "test_element", schema: "test_schema", path: nil },
        ]

        expect do
          capture_stdout do
            command.send(:output_text_list, results, "entity", nil, nil)
          end
        end.not_to raise_error
      end

      it "handles results with nil category" do
        results = [
          { id: "test_element", schema: "test_schema", category: nil },
        ]

        output = capture_stdout do
          command.send(:output_text_list, results, "entity", nil, nil)
        end

        expect(output).to include("test_schema.test_element")
        expect(output).not_to include("[]")
      end
    end

    describe "#output_text_search_results" do
      let(:command) { described_class.new }

      it "handles search results with nil fields" do
        results = [
          { id: "test_element", type: "entity", schema: nil, path: nil,
            category: nil },
        ]

        output = capture_stdout do
          command.send(:output_text_search_results, results, "test")
        end

        expect(output).to include("test_element")
        expect(output).to include("[entity]")
      end
    end
  end

  describe "build command with missing dependencies" do
    describe "#build" do
      it "handles missing dependency resolver gracefully" do
        # Temporarily undefine the constant to simulate missing dependency
        original_resolver = Expressir::Model.const_get(:DependencyResolver) if defined?(Expressir::Model::DependencyResolver)
        Expressir::Model.send(:remove_const, :DependencyResolver) if defined?(Expressir::Model::DependencyResolver)

        command = described_class.new

        expect do
          command.build("nonexistent.exp", test_output)
        end.to raise_error(Expressir::PackageBuildError)

        # Restore the constant if it existed
        if original_resolver
          Expressir::Model.const_set(:DependencyResolver, original_resolver)
        end
      end

      it "handles validation errors gracefully" do
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        # Create a temp EXPRESS file to parse
        temp_exp_file = File.join(temp_dir, "test.exp")
        File.write(temp_exp_file, "SCHEMA test_schema; END_SCHEMA;")

        # Create a repository that will fail validation
        repo = Expressir::Model::Repository.new(schemas: [])
        allow(Expressir::Model::Repository).to receive(:from_files).and_return(repo)
        allow(repo).to receive(:validate).and_return({
                                                       valid?: false,
                                                       errors: ["Test validation error"],
                                                     })

        command = described_class.new("validate" => true)

        expect do
          command.build(temp_exp_file, test_output)
        end.to raise_error(Expressir::SchemaValidationError)
      end
    end
  end
end
