# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "zip"
require "stringio"

RSpec.describe Expressir::Commands::Package,
               "nil guards and original bug fixes" do
  include Expressir::ConsoleHelper

  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "original .empty? on nil bug fix" do
    let(:nil_description_package) { File.join(temp_dir, "nil_desc.ler") }

    before do
      # Create package specifically to reproduce the original bug scenario
      repo = Expressir::Model::Repository.new
      repo.instance_variable_set(:@schemas, [])

      Zip::File.open(nil_description_package, create: true) do |zip|
        # Create metadata hash with nil description - the original bug scenario
        metadata_hash = {
          "name" => "Test Package",
          "version" => "1.0.0",
          "description" => nil, # This nil value caused .empty? to fail
          "created_at" => nil,
          "created_by" => nil,
          "express_mode" => nil,
          "resolution_mode" => nil,
          "serialization_format" => nil,
        }

        zip.get_output_stream("metadata.yaml") do |s|
          s.write(metadata_hash.to_yaml)
        end

        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(repo))
        end

        # Add required index files
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

    context "package info command" do
      it "does not call .empty? on nil description field" do
        command = described_class.new("format" => "text")

        # This should not raise NoMethodError: undefined method `empty?' for nil:NilClass
        expect do
          output = capture_stdout do
            command.info(nil_description_package)
          end

          # Verify output is correct
          expect(output).to include("Name:        Test Package")
          expect(output).to include("Version:     1.0.0")
          # nil description should not appear in output
          expect(output).not_to include("Description:")
        end.not_to raise_error(NoMethodError)
      end

      it "handles multiple nil metadata fields gracefully" do
        command = described_class.new("format" => "text")

        expect do
          output = capture_stdout do
            command.info(nil_description_package)
          end

          # Should only show non-nil fields
          expect(output).to include("Package Information")
          expect(output).to include("Name:")
          expect(output).to include("Version:")
          expect(output).not_to include("Description:")
          expect(output).not_to include("Created:")
          expect(output).not_to include("Created by:")
          expect(output).not_to include("Express mode:")
        end.not_to raise_error
      end
    end
  end

  describe "nil guard testing for all output methods" do
    let(:command) { described_class.new }

    context "output_text_info method" do
      it "handles nil metadata gracefully" do
        nil_metadata = Expressir::Package::Metadata.new(
          name: nil,
          version: nil,
          description: nil,
          created_at: nil,
          created_by: nil,
          express_mode: nil,
          resolution_mode: nil,
          serialization_format: nil,
        )

        empty_repo = Expressir::Model::Repository.new(schemas: [])

        expect do
          capture_stdout do
            command.send(:output_text_info, nil_metadata, empty_repo)
          end
        end.not_to raise_error
      end

      it "handles empty string metadata gracefully" do
        empty_metadata = Expressir::Package::Metadata.new(
          name: "",
          version: "",
          description: "",
          created_at: "",
          created_by: "",
          express_mode: "",
          resolution_mode: "",
          serialization_format: "",
        )

        empty_repo = Expressir::Model::Repository.new(schemas: [])

        expect do
          output = capture_stdout do
            command.send(:output_text_info, empty_metadata, empty_repo)
          end

          # Empty strings should not be displayed
          expect(output).not_to include("Description:")
        end.not_to raise_error
      end

      it "correctly identifies non-empty descriptions" do
        valid_metadata = Expressir::Package::Metadata.new(
          name: "Valid Package",
          version: "1.0.0",
          description: "Valid description",
          created_at: "2023-01-01",
          created_by: "test_user",
          express_mode: "include_all",
          resolution_mode: "resolved",
          serialization_format: "marshal",
        )

        schema = Expressir::Model::Declarations::Schema.new(
          id: "test_schema",
          entities: Array.new(5) do |i|
            Expressir::Model::Declarations::Entity.new(id: "entity#{i}")
          end,
          types: Array.new(3) do |i|
            Expressir::Model::Declarations::Type.new(id: "type#{i}")
          end,
          functions: Array.new(2) do |i|
            Expressir::Model::Declarations::Function.new(id: "func#{i}")
          end,
          rules: [Expressir::Model::Declarations::Rule.new(id: "rule1")],
        )
        repo = Expressir::Model::Repository.new(schemas: [schema])

        output = capture_stdout do
          command.send(:output_text_info, valid_metadata, repo)
        end

        expect(output).to include("Name:        Valid Package")
        expect(output).to include("Description: Valid description")
        expect(output).to include("Created:     2023-01-01")
        expect(output).to include("Created by:  test_user")
      end
    end

    context "output_json_info method" do
      it "handles nil metadata in JSON output" do
        nil_metadata = Expressir::Package::Metadata.new(
          name: nil,
          version: nil,
          description: nil,
        )

        empty_repo = Expressir::Model::Repository.new(schemas: [])

        output = capture_stdout do
          command.send(:output_json_info, nil_metadata, empty_repo)
        end

        json_data = JSON.parse(output)
        expect(json_data["metadata"]["description"]).to be_nil
      end
    end

    context "output_yaml_info method" do
      it "handles nil metadata in YAML output" do
        nil_metadata = Expressir::Package::Metadata.new(
          name: nil,
          version: nil,
          description: nil,
        )

        empty_repo = Expressir::Model::Repository.new(schemas: [])

        output = capture_stdout do
          command.send(:output_yaml_info, nil_metadata, empty_repo)
        end

        yaml_data = YAML.safe_load(output)
        expect(yaml_data["metadata"]["description"]).to be_nil
      end
    end
  end

  describe "nil guards in search engine interactions" do
    let(:command) { described_class.new }
    let(:nil_search_package) { File.join(temp_dir, "nil_search.ler") }

    before do
      # Create package with nil collections in schemas using real objects
      repo = Expressir::Model::Repository.new

      # Create a real Schema object with nil collections
      schema = Expressir::Model::Declarations::Schema.new
      schema.instance_variable_set(:@id, "test_schema")
      schema.instance_variable_set(:@entities, nil)
      schema.instance_variable_set(:@types, nil)
      schema.instance_variable_set(:@functions, nil)
      schema.instance_variable_set(:@procedures, nil)
      schema.instance_variable_set(:@rules, nil)
      schema.instance_variable_set(:@constants, nil)
      schema.instance_variable_set(:@interfaces, nil)

      repo.instance_variable_set(:@schemas, [schema])

      Zip::File.open(nil_search_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(name: "Nil Search Test",
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
    end

    it "handles list command with nil schema collections" do
      command = described_class.new("type" => "entity")

      expect do
        output = capture_stdout do
          command.list(nil_search_package)
        end
        expect(output).to include("Total: 0")
      end.not_to raise_error
    end

    it "handles search command with nil schema collections" do
      command = described_class.new

      expect do
        output = capture_stdout do
          command.search(nil_search_package, "test_pattern")
        end
        expect(output).to include("Total: 0")
      end.not_to raise_error
    end
  end

  describe "nil guards in validation results" do
    let(:command) { described_class.new }

    it "handles nil warnings in validation results" do
      validation_result = {
        valid?: true,
        errors: [],
        warnings: nil, # nil warnings
      }

      expect do
        output = capture_stdout do
          command.send(:output_text_validation, validation_result)
        end
        expect(output).to include("✓ Package is valid")
        expect(output).not_to include("Warnings:")
      end.not_to raise_error
    end

    it "handles nil errors in validation results" do
      validation_result = {
        valid?: false,
        errors: nil, # nil errors - should be handled gracefully
        warnings: [],
      }

      # The method now handles nil errors without calling methods on nil
      expect do
        output = capture_stdout do
          command.send(:output_text_validation, validation_result)
        end
        expect(output).to include("✗ Validation failed")
        expect(output).to include("Errors (0):")
      end.not_to raise_error
    end

    it "handles empty arrays properly" do
      validation_result = {
        valid?: true,
        errors: [],
        warnings: [],
      }

      output = capture_stdout do
        command.send(:output_text_validation, validation_result)
      end

      expect(output).to include("✓ Package is valid")
      expect(output).not_to include("Warnings:")
    end
  end

  describe "nil guards in tree display methods" do
    let(:command) { described_class.new }

    context "build_counts_text method" do
      it "handles schema with nil entity collection" do
        schema = Expressir::Model::Declarations::Schema.new(
          id: "test_schema",
          entities: nil,
          types: [],
          functions: [],
        )

        result = command.send(:build_counts_text, schema)
        expect(result).to eq("")
      end

      it "handles schema with all nil collections" do
        schema = Expressir::Model::Declarations::Schema.new(
          id: "test_schema",
          entities: nil,
          types: nil,
          functions: nil,
        )

        result = command.send(:build_counts_text, schema)
        expect(result).to eq("")
      end

      it "handles mixed nil and empty collections" do
        schema = Expressir::Model::Declarations::Schema.new(
          id: "test_schema",
          entities: nil, # nil
          types: [], # empty array
          functions: [Expressir::Model::Declarations::Function.new(id: "func1")], # non-empty array
        )

        expect do
          result = command.send(:build_counts_text, schema)
          expect(result).to include("function")
        end.not_to raise_error
      end
    end

    context "extract_type_info method" do
      it "handles element with nil type" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: nil,
        )

        result = command.send(:extract_type_info, element)
        expect(result).to eq("ANY")
      end
    end
  end

  describe "edge cases in output formatting" do
    let(:command) { described_class.new }

    context "output_text_list method" do
      it "handles results with nil schema" do
        results = [
          { id: "test_element", schema: nil, path: "test.path", category: nil },
        ]

        expect do
          output = capture_stdout do
            command.send(:output_text_list, results, "entity", nil, nil)
          end
          expect(output).to include("test_element")
        end.not_to raise_error
      end

      it "handles results with nil path when show_path is true" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ "show_path" => true })

        results = [
          { id: "test_element", schema: "test_schema", path: nil,
            category: nil },
        ]

        expect do
          capture_stdout do
            command.send(:output_text_list, results, "entity", nil, nil)
          end
        end.not_to raise_error
      end
    end

    context "output_text_search_results method" do
      it "handles search results with nil fields" do
        results = [
          {
            id: "test_element",
            type: "entity",
            schema: nil,
            path: nil,
            category: nil,
          },
        ]

        expect do
          output = capture_stdout do
            command.send(:output_text_search_results, results, "test_pattern")
          end
          expect(output).to include("test_element")
        end.not_to raise_error
      end
    end
  end
end
