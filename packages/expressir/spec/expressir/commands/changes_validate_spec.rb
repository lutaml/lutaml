# frozen_string_literal: true

require "spec_helper"
require "expressir/commands/changes_validate"

RSpec.describe Expressir::Commands::ChangesValidate do
  let(:valid_fixture) do
    File.join(__dir__, "../../fixtures/changes/simple_change.yaml")
  end

  let(:complete_fixture) do
    File.join(__dir__, "../../fixtures/changes/complete_change.yaml")
  end

  describe "#run" do
    context "with valid file" do
      it "validates successfully" do
        command = described_class.new
        expect { command.run(valid_fixture) }.not_to raise_error
      end

      it "validates successfully with verbose output" do
        command = described_class.new(verbose: true)
        expect do
          command.run(valid_fixture)
        end.to output(/✓ File is valid/).to_stdout
      end

      it "shows schema information with verbose output" do
        command = described_class.new(verbose: true)
        expect do
          command.run(valid_fixture)
        end.to output(/Schema: test_schema/).to_stdout
      end
    end

    context "with --normalize flag" do
      it "normalizes and outputs to stdout by default" do
        command = described_class.new(normalize: true)
        expect do
          command.run(valid_fixture)
        end.to output(/schema: test_schema/).to_stdout
      end

      it "normalizes and saves to output file" do
        require "tempfile"
        Tempfile.create(["output", ".yaml"]) do |f|
          command = described_class.new(normalize: true, output: f.path)
          command.run(valid_fixture)

          # Verify file was written
          content = File.read(f.path)
          expect(content).to include("schema: test_schema")
          expect(content).to include("version: 2")

          # Verify it can be loaded back
          require "expressir/changes"
          schema_change = Expressir::Changes::SchemaChange.from_file(f.path)
          expect(schema_change.schema).to eq("test_schema")
        end
      end

      it "normalizes in place with --in-place flag" do
        require "tempfile"
        Tempfile.create(["test", ".yaml"]) do |f|
          # Copy fixture to temp file
          FileUtils.cp(valid_fixture, f.path)

          command = described_class.new(normalize: true, in_place: true)
          command.run(f.path)

          # Verify file was updated
          content = File.read(f.path)
          expect(content).to include("schema: test_schema")

          # Verify it can be loaded back
          require "expressir/changes"
          schema_change = Expressir::Changes::SchemaChange.from_file(f.path)
          expect(schema_change.schema).to eq("test_schema")
        end
      end

      it "shows success message with verbose output" do
        require "tempfile"
        Tempfile.create(["output", ".yaml"]) do |f|
          command = described_class.new(normalize: true, output: f.path,
                                        verbose: true)
          expect do
            command.run(valid_fixture)
          end.to output(/✓ Normalized file written to/).to_stdout
        end
      end
    end

    context "with invalid options" do
      it "rejects --in-place without --normalize" do
        command = described_class.new(in_place: true)
        command.instance_variable_set(:@test_mode, true)

        expect do
          command.run(valid_fixture)
        end.to raise_error(/--in-place requires --normalize flag/)
      end

      it "rejects both --in-place and --output" do
        command = described_class.new(in_place: true, normalize: true,
                                      output: "test.yaml")
        command.instance_variable_set(:@test_mode, true)

        expect do
          command.run(valid_fixture)
        end.to raise_error(/Cannot use both --in-place and --output/)
      end
    end

    context "with non-existent file" do
      it "reports file not found error" do
        command = described_class.new
        command.instance_variable_set(:@test_mode, true)

        expect do
          command.run("nonexistent.yaml")
        end.to raise_error(/File not found/)
      end
    end

    context "with invalid YAML" do
      it "reports YAML syntax error" do
        require "tempfile"
        Tempfile.create(["invalid", ".yaml"]) do |f|
          f.write("invalid: yaml: syntax:")
          f.flush

          command = described_class.new
          command.instance_variable_set(:@test_mode, true)

          expect do
            command.run(f.path)
          end.to raise_error(/Invalid YAML syntax|Validation failed/)
        end
      end
    end

    context "with complete fixture" do
      it "validates complex structure successfully" do
        command = described_class.new(verbose: true)
        expect do
          command.run(complete_fixture)
        end.to output(/✓ File is valid/).to_stdout
      end

      it "normalizes complex structure" do
        require "tempfile"
        Tempfile.create(["output", ".yaml"]) do |f|
          command = described_class.new(normalize: true, output: f.path)
          command.run(complete_fixture)

          # Verify normalized file preserves structure
          require "expressir/changes"
          original = Expressir::Changes::SchemaChange.from_file(complete_fixture)
          normalized = Expressir::Changes::SchemaChange.from_file(f.path)

          expect(normalized.schema).to eq(original.schema)
          expect(normalized.versions.length).to eq(original.versions.length)
        end
      end
    end
  end
end
