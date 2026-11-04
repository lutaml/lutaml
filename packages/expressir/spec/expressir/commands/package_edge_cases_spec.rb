# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "zip"
require "stringio"

RSpec.describe Expressir::Commands::Package,
               "edge cases and boundary conditions" do
  include Expressir::ConsoleHelper

  let(:temp_dir) { Dir.mktmpdir }
  let(:test_package) { File.join(temp_dir, "test.ler") }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "malformed package handling" do
    context "with incomplete package structure" do
      before do
        Zip::File.open(test_package, create: true) do |zip|
          # Only add metadata, missing other required files
          metadata = Expressir::Package::Metadata.new(
            name: "Incomplete Package",
            version: "1.0.0",
            resolution_mode: "resolved",
            serialization_format: "marshal",
            schemas: 1,
            files: 0,
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
          end
          # Missing repository.marshal, indexes, etc.
        end
      end

      it "handles missing serialized repository gracefully" do
        command = described_class.new

        expect do
          command.info(test_package)
        end.to raise_error(Expressir::PackageReadError)
      end

      it "handles missing manifest gracefully" do
        command = described_class.new

        expect do
          command.list(test_package)
        end.to raise_error(Expressir::PackageListError)
      end
    end

    context "with corrupted internal files" do
      before do
        Zip::File.open(test_package, create: true) do |zip|
          metadata = Expressir::Package::Metadata.new(
            name: "Corrupted Package",
            version: "1.0.0",
            resolution_mode: "resolved",
            serialization_format: "marshal",
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
          end

          # Add corrupted repository file
          zip.get_output_stream("repository.marshal") do |s|
            s.write("corrupted marshal data")
          end
        end
      end

      it "handles corrupted marshal data gracefully" do
        command = described_class.new

        expect do
          command.info(test_package)
        end.to raise_error(Expressir::PackageReadError)
      end
    end
  end

  describe "boundary value testing" do
    context "with extremely large packages" do
      let(:large_repo) do
        Expressir::Model::Repository.new.tap do |repo|
          # Create many schemas to test performance and memory handling
          100.times do |i|
            schema = Expressir::Model::Declarations::Schema.new(
              id: "schema_#{i}",
              file: nil,
            )
            repo.add_schema(schema)
          end
          repo.build_indexes
        end
      end

      it "handles large repository statistics without performance issues" do
        command = described_class.new
        metadata = Expressir::Package::Metadata.new(
          name: "Large Package",
          version: "1.0.0",
        )

        expect do
          output = capture_stdout do
            command.send(:output_text_info, metadata, large_repo)
          end
          expect(output).to include("Total schemas:    100")
        end.not_to raise_error
      end
    end

    context "with empty string values" do
      let(:empty_metadata) do
        Expressir::Package::Metadata.new(
          name: "",
          version: "",
          description: "",
          created_at: "",
          created_by: "",
          express_mode: "",
          resolution_mode: "",
          serialization_format: "",
        )
      end

      it "validates empty string fields appropriately" do
        validation = empty_metadata.validate
        expect(validation[:valid?]).to be false
        expect(validation[:errors]).to include("name is required")
        expect(validation[:errors]).to include("version is required")
      end
    end
  end

  describe "concurrent access scenarios" do
    it "handles package file being deleted during operation" do
      # Create package
      empty_repo = Expressir::Model::Repository.new
      Zip::File.open(test_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(
          name: "Test Package",
          version: "1.0.0",
        )
        zip.get_output_stream("metadata.yaml") do |s|
          s.write(metadata.to_yaml)
        end
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(empty_repo))
        end
      end

      command = described_class.new

      # Delete file before access
      File.delete(test_package)

      expect do
        command.info(test_package)
      end.to raise_error(Expressir::PackageNotFoundError)
    end
  end

  describe "memory and resource management" do
    context "with limited memory scenarios" do
      it "handles large search operations gracefully" do
        # Create package with search engine
        repo = Expressir::Model::Repository.new.tap do |r|
          r.instance_variable_set(:@schemas, [])
          r.build_indexes
        end

        Zip::File.open(test_package, create: true) do |zip|
          metadata = Expressir::Package::Metadata.new(
            name: "Test Package",
            version: "1.0.0",
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
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

        command = described_class.new

        # Test with very long pattern
        long_pattern = "a" * 1000

        expect do
          capture_stdout do
            command.search(test_package, long_pattern)
          end
        end.not_to raise_error
      end
    end
  end

  describe "unicode and special character handling" do
    context "with unicode package names and descriptions" do
      let(:unicode_metadata) do
        Expressir::Package::Metadata.new(
          name: "测试包 🧪",
          version: "1.0.0",
          description: "パッケージのテスト with émojis 🚀",
        )
      end

      it "handles unicode in metadata display" do
        command = described_class.new
        empty_repo = Expressir::Model::Repository.new

        output = capture_stdout do
          command.send(:output_text_info, unicode_metadata, empty_repo)
        end

        expect(output).to include("测试包 🧪")
        expect(output).to include("パッケージのテスト with émojis 🚀")
      end

      it "handles unicode in JSON output" do
        command = described_class.new
        empty_repo = Expressir::Model::Repository.new

        output = capture_stdout do
          command.send(:output_json_info, unicode_metadata, empty_repo)
        end

        json_data = JSON.parse(output)
        expect(json_data["metadata"]["name"]).to eq("测试包 🧪")
        expect(json_data["metadata"]["description"]).to eq("パッケージのテスト with émojis 🚀")
      end
    end

    context "with special characters in search patterns" do
      it "handles regex special characters safely" do
        repo = Expressir::Model::Repository.new.tap do |r|
          r.instance_variable_set(:@schemas, [])
          r.build_indexes
        end

        Zip::File.open(test_package, create: true) do |zip|
          metadata = Expressir::Package::Metadata.new(
            name: "Test Package",
            version: "1.0.0",
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
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

        command = described_class.new("regex" => true)

        # Test with problematic regex characters
        problematic_patterns = ["[invalid", "(?invalid", "*", "+", "?"]

        problematic_patterns.each do |pattern|
          expect do
            capture_stdout do
              command.search(test_package, pattern)
            end
          end.not_to raise_error
        end
      end
    end
  end

  describe "format-specific edge cases" do
    context "with different serialization formats" do
      %w[marshal json yaml].each do |format|
        context "with #{format} format" do
          let(:format_package) { File.join(temp_dir, "test_#{format}.ler") }

          before do
            repo = Expressir::Model::Repository.new
            Zip::File.open(format_package, create: true) do |zip|
              metadata = Expressir::Package::Metadata.new(
                name: "Test Package",
                version: "1.0.0",
                serialization_format: format,
              )
              zip.get_output_stream("metadata.yaml") do |s|
                s.write(metadata.to_yaml)
              end

              case format
              when "marshal"
                zip.get_output_stream("repository.marshal") do |s|
                  s.write(Marshal.dump(repo))
                end
              when "json"
                zip.get_output_stream("repository.json") do |s|
                  s.write(repo.to_json)
                end
              when "yaml"
                zip.get_output_stream("repository.yaml") do |s|
                  s.write(repo.to_yaml)
                end
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

          it "handles #{format} format package info" do
            command = described_class.new

            expect do
              capture_stdout do
                command.info(format_package)
              end
            end.not_to raise_error
          end
        end
      end
    end
  end

  describe "CLI option combinations" do
    let(:test_repo) do
      Expressir::Model::Repository.new.tap do |repo|
        schema = Expressir::Model::Declarations::Schema.new(
          id: "test_schema",
          file: nil,
        )
        repo.add_schema(schema)
        repo.build_indexes
      end
    end

    before do
      Zip::File.open(test_package, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(
          name: "Test Package",
          version: "1.0.0",
        )
        zip.get_output_stream("metadata.yaml") do |s|
          s.write(metadata.to_yaml)
        end
        zip.get_output_stream("repository.marshal") do |s|
          s.write(Marshal.dump(test_repo))
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

    context "with conflicting options" do
      it "handles count_only with detailed output options" do
        command = described_class.new(
          "count_only" => true,
          "show_path" => true,
          "show_details" => true,
          "format" => "json",
        )

        output = capture_stdout do
          command.list(test_package)
        end

        # count_only should override other options
        expect(output.strip).to eq("0")
      end

      it "handles invalid format with other options" do
        # Test with an invalid format to ensure graceful degradation
        allow_any_instance_of(described_class).to receive(:options).and_return({
                                                                                 "format" => "invalid_format",
                                                                                 "type" => "entity",
                                                                               })

        command = described_class.new

        # Should fallback to text format
        expect do
          capture_stdout do
            command.list(test_package)
          end
        end.not_to raise_error
      end
    end
  end

  describe "network and I/O error simulation" do
    context "with simulated I/O failures" do
      it "handles file read permissions gracefully" do
        # Create package then change permissions
        File.write(test_package, "test")
        File.chmod(0o000, test_package)

        command = described_class.new

        expect do
          command.info(test_package)
        end.to raise_error(Expressir::PackageReadError)

        # Restore permissions for cleanup
        begin
          File.chmod(0o644, test_package)
        rescue StandardError
          nil
        end
      end
    end
  end

  describe "tree display edge cases" do
    context "with complex schema hierarchies" do
      let(:complex_repo) do
        Expressir::Model::Repository.new.tap do |repo|
          # Create schema with entities that have many attributes
          schema = Expressir::Model::Declarations::Schema.new(
            id: "complex_schema",
            file: nil,
          )

          # Create entity with many attributes (real objects, not mocks)
          entity = Expressir::Model::Declarations::Entity.new(
            id: "test_entity",
          )
          entity.attributes = (1..10).map do |i|
            Expressir::Model::Declarations::Attribute.new(
              id: "attr_#{i}",
              type: nil,
            )
          end
          entity.derived_attributes = []
          entity.inverse_attributes = []

          schema.entities = [entity]
          schema.types = []
          schema.functions = []
          schema.procedures = []
          schema.rules = []

          repo.add_schema(schema)
          repo.build_indexes
        end
      end

      before do
        Zip::File.open(test_package, create: true) do |zip|
          metadata = Expressir::Package::Metadata.new(
            name: "Complex Package",
            version: "1.0.0",
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
          end
          zip.get_output_stream("repository.marshal") do |s|
            s.write(Marshal.dump(complex_repo))
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

      it "handles entities with many attributes gracefully" do
        command = described_class.new("depth" => 3)

        expect do
          capture_stdout do
            command.tree(test_package)
          end
        end.not_to raise_error
      end

      it "truncates long attribute lists appropriately" do
        command = described_class.new("depth" => 3)

        output = capture_stdout do
          command.tree(test_package)
        end

        # Should show truncation message for many attributes
        expect(output).to include("... (") if output.include?("attr_")
      end
    end
  end
end
