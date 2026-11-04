# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../../../spec/fixtures/package_fixtures"

RSpec.describe Expressir::Commands::Package,
               "using test fixtures for nil scenarios" do
  include Expressir::ConsoleHelper

  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "nil metadata scenarios" do
    let(:nil_metadata_package) { File.join(temp_dir, "nil_metadata.ler") }
    let(:empty_metadata_package) { File.join(temp_dir, "empty_metadata.ler") }

    before do
      Expressir::TestFixtures::PackageFixtures.create_nil_metadata_package(nil_metadata_package)
      Expressir::TestFixtures::PackageFixtures.create_empty_metadata_package(empty_metadata_package)
    end

    describe "#info command with nil metadata fields" do
      it "handles nil description without calling .empty? on nil" do
        command = described_class.new("format" => "text")

        expect do
          output = capture_stdout do
            command.info(nil_metadata_package)
          end

          # Should show name and version but not description
          expect(output).to include("Name:        Test Package")
          expect(output).to include("Version:     1.0.0")
          expect(output).not_to include("Description:")
        end.not_to raise_error(NoMethodError)
      end

      it "handles nil created_at gracefully" do
        command = described_class.new("format" => "text")

        output = capture_stdout do
          command.info(nil_metadata_package)
        end

        expect(output).not_to include("Created:")
      end

      it "handles nil created_by gracefully" do
        command = described_class.new("format" => "text")

        output = capture_stdout do
          command.info(nil_metadata_package)
        end

        expect(output).not_to include("Created by:")
      end

      it "handles nil express_mode gracefully" do
        command = described_class.new("format" => "text")

        output = capture_stdout do
          command.info(nil_metadata_package)
        end

        expect(output).not_to include("Express mode:")
      end

      it "handles empty string metadata fields" do
        command = described_class.new("format" => "text")

        output = capture_stdout do
          command.info(empty_metadata_package)
        end

        # Empty strings should not be displayed
        expect(output).not_to include("Description:")
      end

      it "outputs valid JSON with nil fields" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.info(nil_metadata_package)
        end

        json_data = JSON.parse(output)
        expect(json_data["metadata"]["name"]).to eq("Test Package")
        expect(json_data["metadata"]["description"]).to be_nil
      end

      it "outputs valid YAML with nil fields" do
        command = described_class.new("format" => "yaml")

        output = capture_stdout do
          command.info(nil_metadata_package)
        end

        yaml_data = YAML.safe_load(output)
        expect(yaml_data["metadata"]["name"]).to eq("Test Package")
        expect(yaml_data["metadata"]["description"]).to be_nil
      end
    end
  end

  describe "empty repository scenarios" do
    let(:empty_repo_package) { File.join(temp_dir, "empty_repo.ler") }
    let(:nil_collections_package) { File.join(temp_dir, "nil_collections.ler") }

    before do
      Expressir::TestFixtures::PackageFixtures.create_empty_repository_package(empty_repo_package)
      Expressir::TestFixtures::PackageFixtures.create_nil_collections_package(nil_collections_package)
    end

    describe "#list command with empty repositories" do
      it "handles completely empty repository" do
        command = described_class.new("type" => "entity")

        expect do
          capture_stdout do
            command.list(empty_repo_package)
          end

          # Should handle gracefully, possibly with empty results
        end.not_to raise_error
      end

      it "handles repository with nil schemas collection" do
        command = described_class.new("type" => "entity")

        expect do
          capture_stdout do
            command.list(empty_repo_package)
          end
        end.not_to raise_error
      end

      it "handles schemas with nil entity collections" do
        command = described_class.new("type" => "entity")

        expect do
          output = capture_stdout do
            command.list(nil_collections_package)
          end

          # Should return empty results for entities
          if command.options["format"] == "json"
            results = JSON.parse(output)
            expect(results).to be_empty
          end
        end.not_to raise_error
      end

      it "handles count_only with empty repository" do
        command = described_class.new("type" => "entity", "count_only" => true)

        output = capture_stdout do
          command.list(empty_repo_package)
        end

        expect(output.strip).to eq("0")
      end

      it "handles different element types with nil collections" do
        %w[entity type function procedure rule].each do |element_type|
          command = described_class.new("type" => element_type,
                                        "count_only" => true)

          expect do
            output = capture_stdout do
              command.list(nil_collections_package)
            end
            expect(output.strip).to eq("0")
          end.not_to raise_error
        end
      end
    end

    describe "#search command with no matches" do
      it "handles search with no results" do
        command = described_class.new

        expect do
          capture_stdout do
            command.search(empty_repo_package, "nonexistent_element")
          end
        end.not_to raise_error
      end

      it "returns empty JSON array for no matches" do
        command = described_class.new("format" => "json")

        output = capture_stdout do
          command.search(empty_repo_package, "nonexistent")
        end

        results = JSON.parse(output)
        expect(results).to be_empty
      end

      it "handles wildcard patterns with no matches" do
        command = described_class.new

        expect do
          capture_stdout do
            command.search(empty_repo_package, "*.nonexistent")
          end
        end.not_to raise_error
      end

      it "handles regex patterns with no matches" do
        command = described_class.new("regex" => true)

        expect do
          capture_stdout do
            command.search(empty_repo_package, "^nonexistent.*")
          end
        end.not_to raise_error
      end

      it "handles count_only with no matches" do
        command = described_class.new("count_only" => true)

        output = capture_stdout do
          command.search(empty_repo_package, "nonexistent")
        end

        expect(output.strip).to eq("0")
      end
    end

    describe "#tree command with empty schemas" do
      it "displays appropriate message for empty repository" do
        command = described_class.new

        output = capture_stdout do
          command.tree(empty_repo_package)
        end

        expect(output).to include("No schemas found")
      end

      it "handles schema filter with empty repository" do
        command = described_class.new("schema" => "nonexistent_schema")

        output = capture_stdout do
          command.tree(empty_repo_package)
        end

        expect(output).to include("No schemas found")
      end

      it "handles type filter with nil collections" do
        command = described_class.new("type" => "entity")

        expect do
          capture_stdout do
            command.tree(nil_collections_package)
          end
        end.not_to raise_error
      end

      it "handles depth limits with empty schemas" do
        command = described_class.new("depth" => 2)

        output = capture_stdout do
          command.tree(empty_repo_package)
        end

        expect(output).to include("No schemas found")
      end

      it "handles counts option with empty schemas" do
        command = described_class.new("counts" => true)

        output = capture_stdout do
          command.tree(empty_repo_package)
        end

        expect(output).to include("No schemas found")
      end
    end
  end

  describe "nil attributes scenarios" do
    let(:nil_attributes_package) { File.join(temp_dir, "nil_attributes.ler") }

    before do
      Expressir::TestFixtures::PackageFixtures.create_nil_attributes_package(nil_attributes_package)
    end

    describe "tree display with nil attribute collections" do
      it "handles entities with nil attributes gracefully" do
        command = described_class.new("depth" => 3)

        expect do
          capture_stdout do
            command.tree(nil_attributes_package)
          end
        end.not_to raise_error
      end

      it "handles attribute type filtering with nil collections" do
        command = described_class.new("type" => "attribute")

        expect do
          capture_stdout do
            command.tree(nil_attributes_package)
          end
        end.not_to raise_error
      end

      it "handles derived_attribute filtering with nil collections" do
        command = described_class.new("type" => "derived_attribute")

        expect do
          capture_stdout do
            command.tree(nil_attributes_package)
          end
        end.not_to raise_error
      end

      it "handles inverse_attribute filtering with nil collections" do
        command = described_class.new("type" => "inverse_attribute")

        expect do
          capture_stdout do
            command.tree(nil_attributes_package)
          end
        end.not_to raise_error
      end
    end

    describe "list command with nil attributes" do
      it "handles attribute listing with nil collections" do
        command = described_class.new("type" => "attribute")

        expect do
          capture_stdout do
            command.list(nil_attributes_package)
          end
        end.not_to raise_error
      end
    end

    describe "search command with nil attributes" do
      it "handles attribute search with nil collections" do
        command = described_class.new("type" => "attribute")

        expect do
          capture_stdout do
            command.search(nil_attributes_package, "test_attr")
          end
        end.not_to raise_error
      end
    end
  end

  describe "corrupted package scenarios" do
    let(:missing_files_package) { File.join(temp_dir, "missing_files.ler") }
    let(:corrupted_package) { File.join(temp_dir, "corrupted.ler") }
    let(:malformed_yaml_package) { File.join(temp_dir, "malformed_yaml.ler") }

    before do
      Expressir::TestFixtures::PackageFixtures.create_missing_files_package(missing_files_package)
      Expressir::TestFixtures::PackageFixtures.create_corrupted_package(corrupted_package)
      Expressir::TestFixtures::PackageFixtures.create_malformed_yaml_package(malformed_yaml_package)
    end

    describe "#validate command with invalid packages" do
      it "handles package with missing files" do
        command = described_class.new

        expect do
          command.validate(missing_files_package)
        end.to raise_error(Expressir::PackageValidationError)
      end

      it "handles corrupted marshal data" do
        command = described_class.new

        expect do
          command.validate(corrupted_package)
        end.to raise_error(Expressir::PackageValidationError)
      end

      it "handles malformed YAML metadata" do
        command = described_class.new

        expect do
          command.info(malformed_yaml_package)
        end.to raise_error(Expressir::PackageReadError)
      end

      it "provides appropriate error messages for validation failures" do
        command = described_class.new("format" => "text")

        # Should not be nil method errors
        expect do
          capture_stderr do
            command.validate(missing_files_package)
          rescue Expressir::Error
            # Expected
          end
        end.not_to raise_error(NoMethodError)
      end
    end

    describe "#extract command with corrupted packages" do
      let(:extract_dir) { File.join(temp_dir, "extracted") }

      it "handles missing required files gracefully" do
        command = described_class.new("output" => extract_dir)

        # Should extract what's available
        expect do
          command.extract(missing_files_package)
        end.not_to raise_error
      end

      it "handles corrupted ZIP structure" do
        # Create completely invalid file
        invalid_package = File.join(temp_dir, "invalid.ler")
        File.write(invalid_package, "not a zip file")

        command = described_class.new("output" => extract_dir)

        expect do
          command.extract(invalid_package)
        end.to raise_error(Expressir::PackageExtractError)
      end
    end

    describe "#build command with missing files/invalid inputs" do
      it "handles non-existent schema files" do
        command = described_class.new

        expect do
          command.build("non/existent/schema.exp",
                        File.join(temp_dir, "output.ler"))
        end.to raise_error(Expressir::PackageBuildError)
      end

      it "handles invalid output paths" do
        command = described_class.new

        expect do
          command.build("spec/syntax/single.exp", "/invalid/path/output.ler")
        end.to raise_error(Expressir::PackageBuildError)
      end
    end
  end

  describe "mixed data scenarios" do
    let(:mixed_package) { File.join(temp_dir, "mixed_data.ler") }

    before do
      Expressir::TestFixtures::PackageFixtures.create_mixed_data_package(mixed_package)
    end

    it "handles packages with mix of nil and valid metadata" do
      command = described_class.new("format" => "text")

      output = capture_stdout do
        command.info(mixed_package)
      end

      expect(output).to include("Name:        Mixed Data Package")
      expect(output).to include("Description: Valid description")
      expect(output).not_to include("Created by:") # nil field should be skipped
      expect(output).to include("Express mode:         include_all")
    end

    it "handles schemas with mixed nil and valid collections" do
      command = described_class.new("type" => "entity")

      expect do
        output = capture_stdout do
          command.list(mixed_package)
        end

        # Should find the valid entity
        expect(output).to include("valid_entity")
      end.not_to raise_error
    end

    it "handles tree display with mixed collections" do
      command = described_class.new

      expect do
        output = capture_stdout do
          command.tree(mixed_package)
        end

        expect(output).to include("mixed_schema")
        expect(output).to include("valid_entity")
      end.not_to raise_error
    end
  end

  describe "search scenarios with empty results" do
    let(:empty_search_package) { File.join(temp_dir, "empty_search.ler") }

    before do
      Expressir::TestFixtures::PackageFixtures.create_empty_search_package(empty_search_package)
    end

    it "handles search patterns that match nothing" do
      command = described_class.new

      output = capture_stdout do
        command.search(empty_search_package, "nonexistent_pattern")
      end

      expect(output).to include("Total: 0")
    end

    it "handles complex wildcard patterns with no matches" do
      command = described_class.new

      expect do
        capture_stdout do
          command.search(empty_search_package, "*.*.nonexistent")
        end
      end.not_to raise_error
    end

    it "handles type-specific searches with no matches" do
      %w[entity type function].each do |element_type|
        command = described_class.new("type" => element_type)

        expect do
          capture_stdout do
            command.search(empty_search_package, "anything")
          end
        end.not_to raise_error
      end
    end
  end
end
