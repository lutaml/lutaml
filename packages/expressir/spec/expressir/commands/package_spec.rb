# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "stringio"
require "zip"

RSpec.describe Expressir::Commands::Package do
  include Expressir::ConsoleHelper

  let(:temp_dir) { Dir.mktmpdir }
  let(:test_output) { File.join(temp_dir, "test.ler") }
  let(:extract_dir) { File.join(temp_dir, "extracted") }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#build" do
    let(:root_schema_path) { "spec/syntax/single.exp" }

    context "when building a package successfully" do
      it "creates a package file" do
        # Skip if dependency resolver not implemented yet
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        command = described_class.new
        expect do
          command.build(root_schema_path, test_output)
        end.not_to raise_error
        expect(File.exist?(test_output)).to be true
      end

      it "accepts package metadata options" do
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        command = described_class.new(
          "name" => "Test Package",
          "version" => "2.0.0",
          "description" => "Test description",
        )

        expect do
          command.build(root_schema_path, test_output)
        end.not_to raise_error
      end

      it "accepts express_mode option" do
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        command = described_class.new("express_mode" => "include_all")
        expect do
          command.build(root_schema_path, test_output)
        end.not_to raise_error
      end

      it "accepts resolution_mode option" do
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        command = described_class.new("resolution_mode" => "resolved")
        expect do
          command.build(root_schema_path, test_output)
        end.not_to raise_error
      end

      it "accepts serialization_format option" do
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        command = described_class.new("serialization_format" => "marshal")
        expect do
          command.build(root_schema_path, test_output)
        end.not_to raise_error
      end
    end

    context "when validation is enabled" do
      it "validates the repository before packaging" do
        skip "Dependency resolver not yet implemented" unless defined?(Expressir::Model::DependencyResolver)

        command = described_class.new("validate" => true)
        expect do
          command.build(root_schema_path, test_output)
        end.not_to raise_error
      end
    end

    context "when there are errors" do
      it "exits with error for non-existent schema file" do
        command = described_class.new
        expect do
          command.build("nonexistent.exp", test_output)
        end.to raise_error(Expressir::PackageBuildError)
      end
    end
  end

  describe "#info" do
    let(:test_package) { File.join(temp_dir, "info_test.ler") }

    before do
      # Create a minimal test package for info command testing
      repo = Expressir::Model::Repository.new
      schema = Expressir::Model::Declarations::Schema.new(id: "test_schema",
                                                          file: nil)
      repo.add_schema(schema)

      Zip::File.open(test_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(
          name: "Test Package",
          version: "1.0.0",
          description: "Test description",
        )
        zip.get_output_stream("metadata.yaml") { |s| s.write(metadata.to_yaml) }
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(repo))
        end
        zip.get_output_stream("entity_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("type_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("reference_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
      end
    end

    context "with a valid package" do
      it "displays package information in text format" do
        command = described_class.new("format" => "text")

        output = capture_stdout do
          command.info(test_package)
        end

        expect(output).to include("Test Package")
        expect(output).to include("1.0.0")
        expect(output).to include("Test description")
      end

      it "displays package information in JSON format" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.info(test_package)
        end

        json_data = JSON.parse(output)
        expect(json_data["metadata"]["name"]).to eq("Test Package")
      end

      it "displays package information in YAML format" do
        command = described_class.new("format" => "yaml")

        output = capture_stdout do
          command.info(test_package)
        end

        yaml_data = YAML.safe_load(output)
        expect(yaml_data["metadata"]["name"]).to eq("Test Package")
      end
    end

    context "with nil metadata fields" do
      let(:nil_package) { File.join(temp_dir, "nil_info_test.ler") }

      before do
        repo = Expressir::Model::Repository.new
        Zip::File.open(nil_package, create: true) do |zip|
          # Create metadata with nil description to test the original bug
          metadata_hash = {
            "name" => "Test Package",
            "version" => "1.0.0",
            "description" => nil,
            "created_at" => nil,
            "created_by" => nil,
          }
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata_hash.to_yaml)
          end
          zip.get_output_stream("repository.marshal") do |s|
            s.write(Marshal.dump(repo))
          end
          zip.get_output_stream("entity_index.marshal") do |s|
            s.write(Marshal.dump({}))
          end
          zip.get_output_stream("type_index.marshal") do |s|
            s.write(Marshal.dump({}))
          end
          zip.get_output_stream("reference_index.marshal") do |s|
            s.write(Marshal.dump({}))
          end
        end
      end

      it "handles nil description without calling .empty? on nil" do
        command = described_class.new("format" => "text")

        expect do
          output = capture_stdout do
            command.info(nil_package)
          end

          expect(output).to include("Test Package")
          expect(output).not_to include("Description:")
        end.not_to raise_error(NoMethodError)
      end

      it "handles nil fields in JSON format" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.info(nil_package)
        end

        json_data = JSON.parse(output)
        expect(json_data["metadata"]["description"]).to be_nil
      end
    end

    context "when package does not exist" do
      it "exits with error" do
        command = described_class.new
        expect { command.info("nonexistent.ler") }.to raise_error(Expressir::PackageNotFoundError)
      end
    end
  end

  describe "#validate" do
    context "with a valid package" do
      it "validates successfully in text format" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("format" => "text")
        expect { command.validate("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "validates successfully in JSON format" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("format" => "json")
        expect { command.validate("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "supports strict mode" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("strict" => true)
        expect { command.validate("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "when package does not exist" do
      it "exits with error" do
        command = described_class.new
        expect do
          command.validate("nonexistent.ler")
        end.to raise_error(Expressir::PackageNotFoundError)
      end
    end
  end

  describe "#extract" do
    context "with a valid package" do
      it "extracts package contents" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("output" => extract_dir)
        expect { command.extract("spec/fixtures/test.ler") }.not_to raise_error
        expect(Dir.exist?(extract_dir)).to be true
      end
    end

    context "when package does not exist" do
      it "exits with error" do
        command = described_class.new("output" => extract_dir)
        expect { command.extract("nonexistent.ler") }.to raise_error(Expressir::PackageExtractError)
      end
    end

    context "when output option is not provided" do
      it "requires output directory" do
        command = described_class.new
        expect { command.extract("test.ler") }.to raise_error(Expressir::MissingRequiredArgumentError)
      end
    end
  end

  describe "#list" do
    let(:list_test_package) { File.join(temp_dir, "list_test.ler") }
    let(:empty_list_package) { File.join(temp_dir, "empty_list.ler") }

    before do
      # Create package with entities for list testing
      repo = Expressir::Model::Repository.new
      schema = Expressir::Model::Declarations::Schema.new(id: "test_schema",
                                                          file: nil)

      entity = Expressir::Model::Declarations::Entity.new(id: "test_entity")
      entity.attributes = []
      schema.entities = [entity]
      schema.types = []
      schema.functions = []

      repo.add_schema(schema)
      repo.build_indexes

      Zip::File.open(list_test_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(name: "List Test",
                                                    version: "1.0.0")
        zip.get_output_stream("metadata.yaml") { |s| s.write(metadata.to_yaml) }
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(repo))
        end
        zip.get_output_stream("entity_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("type_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("reference_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
      end

      # Create package with empty repository
      empty_repo = Expressir::Model::Repository.new
      empty_repo.instance_variable_set(:@schemas, [])
      empty_repo.build_indexes

      Zip::File.open(empty_list_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(name: "Empty List Test",
                                                    version: "1.0.0")
        zip.get_output_stream("metadata.yaml") { |s| s.write(metadata.to_yaml) }
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(empty_repo))
        end
        zip.get_output_stream("entity_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("type_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
        zip.get_output_stream("reference_index.marshal") do |s|
          s.write(Marshal.dump({}))
        end
      end
    end

    context "with a valid package" do
      it "lists entities by default" do
        command = described_class.new("type" => "entity")

        output = capture_stdout do
          command.list(list_test_package)
        end

        expect(output).to include("test_entity")
      end

      it "lists entities in JSON format" do
        command = described_class.new("type" => "entity", "format" => "json")

        output = capture_stdout do
          command.list(list_test_package)
        end

        results = JSON.parse(output)
        expect(results).to be_an(Array)
        expect(results.first["id"]).to eq("test_entity") if results.any?
      end

      it "shows count only when requested" do
        command = described_class.new("type" => "entity", "count_only" => true)

        output = capture_stdout do
          command.list(list_test_package)
        end

        expect(output.strip).to eq("1")
      end
    end

    context "with empty repository" do
      it "handles empty repository gracefully" do
        command = described_class.new("type" => "entity")

        expect do
          output = capture_stdout do
            command.list(empty_list_package)
          end
          expect(output).to include("Total: 0")
        end.not_to raise_error
      end

      it "returns empty JSON array for empty repository" do
        command = described_class.new("type" => "entity", "format" => "json")

        output = capture_stdout do
          command.list(empty_list_package)
        end

        results = JSON.parse(output)
        expect(results).to be_empty
      end

      it "shows count 0 for empty repository" do
        command = described_class.new("type" => "entity", "count_only" => true)

        output = capture_stdout do
          command.list(empty_list_package)
        end

        expect(output.strip).to eq("0")
      end
    end

    context "when package does not exist" do
      it "exits with error" do
        command = described_class.new
        expect { command.list("nonexistent.ler") }.to raise_error(Expressir::PackageNotFoundError)
      end
    end
  end

  describe "#search" do
    let(:search_test_package) { File.join(temp_dir, "search_test.ler") }
    let(:empty_search_package) { File.join(temp_dir, "empty_search.ler") }

    before do
      # Create package with searchable content
      repo = Expressir::Model::Repository.new
      schema = Expressir::Model::Declarations::Schema.new(id: "test_schema",
                                                          file: nil)

      entity = Expressir::Model::Declarations::Entity.new(id: "action_entity")
      entity.attributes = []
      entity.parent = schema # Set parent for path resolution
      schema.entities = [entity]

      repo.add_schema(schema)
      repo.build_indexes

      Zip::File.open(search_test_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(name: "Search Test",
                                                    version: "1.0.0")
        zip.get_output_stream("metadata.yaml") { |s| s.write(metadata.to_yaml) }
        # Marshal the repository with indexes already built
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(repo))
        end
        # Note: Indexes are included in the repository marshal
      end

      # Create empty package for no-match testing
      empty_repo = Expressir::Model::Repository.new
      empty_repo.instance_variable_set(:@schemas, [])
      empty_repo.build_indexes

      Zip::File.open(empty_search_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(name: "Empty Search Test",
                                                    version: "1.0.0")
        zip.get_output_stream("metadata.yaml") { |s| s.write(metadata.to_yaml) }
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(empty_repo))
        end
      end
    end

    context "with a valid package" do
      it "searches by simple pattern" do
        command = described_class.new

        output = capture_stdout do
          command.search(search_test_package, "action")
        end

        expect(output).to include("action_entity")
      end

      it "searches in JSON format" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.search(search_test_package, "action")
        end

        results = JSON.parse(output)
        expect(results).to be_an(Array)
        expect(results.first["id"]).to eq("action_entity") if results.any?
      end

      it "shows count only when requested" do
        command = described_class.new("count_only" => true)

        output = capture_stdout do
          command.search(search_test_package, "action")
        end

        expect(output.strip).to eq("1")
      end
    end

    context "with no matches" do
      it "handles search with no results gracefully" do
        command = described_class.new

        expect do
          output = capture_stdout do
            command.search(empty_search_package, "nonexistent")
          end
          expect(output).to include("Total: 0")
        end.not_to raise_error
      end

      it "returns empty JSON array for no matches" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.search(empty_search_package, "nonexistent")
        end

        results = JSON.parse(output)
        expect(results).to be_empty
      end

      it "shows count 0 for no matches" do
        command = described_class.new("count_only" => true)

        output = capture_stdout do
          command.search(empty_search_package, "nonexistent")
        end

        expect(output.strip).to eq("0")
      end
    end

    context "when package does not exist" do
      it "exits with error" do
        command = described_class.new
        expect do
          command.search("nonexistent.ler", "action")
        end.to raise_error(Expressir::PackageNotFoundError)
      end
    end
  end
end
