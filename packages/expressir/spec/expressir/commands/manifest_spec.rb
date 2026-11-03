# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Expressir::Commands::Manifest do
  include Expressir::ConsoleHelper

  let(:fixtures_dir) { File.join(__dir__, "..", "..", "fixtures") }
  let(:temp_dir) { Dir.mktmpdir }
  let(:test_output) { File.join(temp_dir, "test_manifest.yaml") }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#validate" do
    context "without --check-references flag" do
      let(:manifest_path) { "#{fixtures_dir}/manifest/valid_manifest.yaml" }
      let(:command) { described_class.new }

      it "validates file existence" do
        output = capture_stdout do
          command.validate(manifest_path)
        end

        expect(output).to include("Manifest is valid")
      end

      it "validates path completeness" do
        incomplete_manifest = "#{fixtures_dir}/manifest/incomplete_paths_manifest.yaml"
        command = described_class.new

        output = capture_stdout do
          command.validate(incomplete_manifest)
        end

        expect(output).to include("Manifest is valid")
        expect(output).to include("Warnings")
        expect(output).to include("empty_path_schema")
      end

      it "does not validate referential integrity by default" do
        unresolved_manifest = "#{fixtures_dir}/manifest/unresolved_references_manifest.yaml"
        command = described_class.new

        output = capture_stdout do
          command.validate(unresolved_manifest)
        end

        # Should pass without checking references
        expect(output).to include("Manifest is valid")
      end

      it "displays success message for valid manifest" do
        output = capture_stdout do
          command.validate(manifest_path)
        end

        expect(output).to include("✓")
        expect(output).to include("Manifest is valid")
      end

      it "displays errors for missing files" do
        missing_files_manifest = "#{fixtures_dir}/manifest/missing_files_manifest.yaml"
        command = described_class.new

        expect do
          capture_stdout do
            command.validate(missing_files_manifest)
          end
        end.to raise_error(Thor::Error)
      end
    end

    context "with --check-references flag" do
      let(:valid_manifest) do
        "#{fixtures_dir}/manifest/valid_references_manifest.yaml"
      end
      let(:unresolved_manifest) do
        "#{fixtures_dir}/manifest/unresolved_references_manifest.yaml"
      end

      it "validates referential integrity" do
        command = described_class.new
        command.options = { "check_references" => true }

        output = capture_stdout do
          command.validate(valid_manifest)
        end

        expect(output).to include("Manifest is valid")
      end

      it "displays referential integrity errors" do
        command = described_class.new
        command.options = { "check_references" => true }

        expect do
          output = capture_stdout do
            command.validate(unresolved_manifest)
          end
          expect(output).to include("Reference Errors")
          expect(output).to include("nonexistent_schema")
        end.to raise_error(Thor::Error)
      end

      it "exits with code 0 when all checks pass" do
        command = described_class.new
        command.options = { "check_references" => true }

        expect do
          capture_stdout do
            command.validate(valid_manifest)
          end
        end.not_to raise_error
      end

      it "exits with code 1 when referential checks fail" do
        command = described_class.new
        command.options = { "check_references" => true }

        expect do
          capture_stdout do
            command.validate(unresolved_manifest)
          end
        end.to raise_error(Thor::Error)
      end
    end

    context "with --verbose flag" do
      let(:manifest_path) { "#{fixtures_dir}/manifest/valid_manifest.yaml" }

      it "shows detailed validation progress" do
        command = described_class.new
        command.options = { "verbose" => true }

        output = capture_stdout do
          command.validate(manifest_path)
        end

        expect(output).to include("Validating manifest")
      end

      it "shows schema counts" do
        command = described_class.new
        command.options = { "verbose" => true }

        output = capture_stdout do
          command.validate(manifest_path)
        end

        expect(output).to include("Total schemas")
        expect(output).to include("Resolved schemas")
      end

      it "shows 'Checking referential integrity...' message when enabled" do
        command = described_class.new
        command.options = { "verbose" => true, "check_references" => true }
        valid_manifest = "#{fixtures_dir}/manifest/valid_references_manifest.yaml"

        output = capture_stdout do
          command.validate(valid_manifest)
        end

        expect(output).to include("Checking referential integrity")
      end
    end

    context "with non-existent manifest" do
      it "displays error message" do
        command = described_class.new

        expect do
          output = capture_stdout do
            command.validate("nonexistent_manifest.yaml")
          end
          expect(output).to include("Error")
          expect(output).to include("not found")
        end.to raise_error(Thor::Error)
      end

      it "exits with code 1" do
        command = described_class.new

        expect do
          capture_stdout do
            command.validate("nonexistent_manifest.yaml")
          end
        end.to raise_error(Thor::Error)
      end
    end

    context "output formatting" do
      let(:missing_files_manifest) do
        "#{fixtures_dir}/manifest/missing_files_manifest.yaml"
      end
      let(:incomplete_manifest) do
        "#{fixtures_dir}/manifest/incomplete_paths_manifest.yaml"
      end
      let(:unresolved_manifest) do
        "#{fixtures_dir}/manifest/unresolved_references_manifest.yaml"
      end

      it "displays file errors in separate section" do
        command = described_class.new

        expect do
          output = capture_stdout do
            command.validate(missing_files_manifest)
          end
          expect(output).to include("File Errors")
        end.to raise_error(Thor::Error)
      end

      it "displays path warnings in separate section" do
        command = described_class.new

        output = capture_stdout do
          command.validate(incomplete_manifest)
        end

        expect(output).to include("Warnings")
      end

      it "displays reference errors in separate section" do
        command = described_class.new
        command.options = { "check_references" => true }

        expect do
          output = capture_stdout do
            command.validate(unresolved_manifest)
          end
          expect(output).to include("Reference Errors")
        end.to raise_error(Thor::Error)
      end

      it "shows error counts" do
        command = described_class.new

        expect do
          output = capture_stdout do
            command.validate(missing_files_manifest)
          end
          expect(output).to match(/File Errors \(\d+\)/)
        end.to raise_error(Thor::Error)
      end

      it "shows warning counts" do
        command = described_class.new

        output = capture_stdout do
          command.validate(incomplete_manifest)
        end

        expect(output).to match(/Warnings \(\d+\)/)
      end
    end
  end

  describe "#create" do
    let(:root_schema) { "#{fixtures_dir}/schemas/test_schema.exp" }

    it "creates a manifest file" do
      command = described_class.new
      command.options = { "output" => test_output }

      expect do
        capture_stdout do
          command.create(root_schema)
        end
      end.not_to raise_error

      expect(File.exist?(test_output)).to be true
    end

    it "displays success message" do
      command = described_class.new
      command.options = { "output" => test_output }

      output = capture_stdout do
        command.create(root_schema)
      end

      expect(output).to include("✓")
      expect(output).to include("Manifest created")
    end

    it "shows resolved schema count" do
      command = described_class.new
      command.options = { "output" => test_output }

      output = capture_stdout do
        command.create(root_schema)
      end

      expect(output).to include("Resolved schemas")
    end

    it "uses Validator for path completeness warnings" do
      # Create a schema that references another schema
      schema_with_ref = "#{fixtures_dir}/schemas/schema_with_use.exp"
      command = described_class.new
      command.options = { "output" => test_output }

      output = capture_stdout do
        command.create(schema_with_ref)
      end

      # The test_schema should be resolved, schema_with_use should be in manifest
      expect(output).to include("Manifest created")
    end

    context "with verbose flag" do
      it "shows detailed progress" do
        command = described_class.new
        command.options = { "output" => test_output, "verbose" => true }

        output = capture_stdout do
          command.create(root_schema)
        end

        expect(output).to include("Creating manifest")
      end
    end

    context "with non-existent root schema" do
      it "displays error and exits" do
        command = described_class.new
        command.options = { "output" => test_output }

        expect do
          output = capture_stdout do
            command.create("nonexistent.exp")
          end
          expect(output).to include("Error")
          expect(output).to include("not found")
        end.to raise_error(Thor::Error)
      end
    end

    context "without output option" do
      it "displays error message" do
        # Thor requires options, so this will fail at the Thor level
        command = described_class.new
        command.options = {}

        expect do
          capture_stdout do
            command.create(root_schema)
          end
        end.to raise_error(Thor::Error)
      end
    end
  end
end
