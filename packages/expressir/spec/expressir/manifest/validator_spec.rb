# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/expressir/manifest/validator"

RSpec.describe Expressir::Manifest::Validator do
  let(:fixtures_dir) { File.join(__dir__, "..", "..", "fixtures") }

  describe "#initialize" do
    let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/valid_manifest.yaml") }

    it "initializes with manifest and options" do
      validator = described_class.new(manifest, verbose: true)
      expect(validator.manifest).to eq(manifest)
      expect(validator.options).to eq({ verbose: true })
    end

    it "extracts base directories from manifest during initialization" do
      validator = described_class.new(manifest)
      # Base dirs are private, but we can verify they don't cause errors
      expect(validator).to be_a(described_class)
    end
  end

  describe "#validate_file_existence" do
    context "when all files exist" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/valid_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "returns empty error array" do
        errors = validator.validate_file_existence
        expect(errors).to be_empty
      end
    end

    context "when some files are missing" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/missing_files_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "returns errors for missing files" do
        errors = validator.validate_file_existence
        expect(errors).not_to be_empty
        expect(errors.size).to eq(1)
      end

      it "includes schema ID in error message" do
        errors = validator.validate_file_existence
        error = errors.first
        expect(error[:schema]).to eq("missing_schema")
      end

      it "includes file path in error message" do
        errors = validator.validate_file_existence
        error = errors.first
        expect(error[:path]).to include("nonexistent.exp")
      end

      it "includes descriptive message" do
        errors = validator.validate_file_existence
        error = errors.first
        expect(error[:message]).to include("Schema file not found")
        expect(error[:message]).to include("missing_schema")
      end
    end

    context "when paths are null or empty" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/incomplete_paths_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "skips validation for null and empty paths" do
        errors = validator.validate_file_existence
        # Should only validate resolved_schema, skip empty_path_schema and null_path_schema
        expect(errors).to be_empty
      end
    end
  end

  describe "#validate_path_completeness" do
    context "when all paths are present" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/valid_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "returns empty warning array" do
        warnings = validator.validate_path_completeness
        expect(warnings).to be_empty
      end
    end

    context "when some paths are empty" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/incomplete_paths_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "returns warnings for incomplete paths" do
        warnings = validator.validate_path_completeness
        expect(warnings).not_to be_empty
        expect(warnings.size).to eq(1) # empty_path_schema only
      end

      it "includes schema ID in warning message" do
        warnings = validator.validate_path_completeness
        schema_ids = warnings.map { |w| w[:schema] }
        expect(schema_ids).to include("empty_path_schema")
      end

      it "includes descriptive message with schema name" do
        warnings = validator.validate_path_completeness
        warning = warnings.first
        expect(warning[:message]).to include("has no path specified")
        expect(warning[:message]).to include("please provide path")
      end
    end

    context "with only null paths" do
      let(:manifest) do
        m = Expressir::SchemaManifest.new
        m.schemas << Expressir::SchemaManifestEntry.new(id: "null_schema",
                                                        path: nil)
        m
      end
      let(:validator) { described_class.new(manifest) }

      it "returns warning for null path" do
        warnings = validator.validate_path_completeness
        expect(warnings.size).to eq(1)
        expect(warnings.first[:schema]).to eq("null_schema")
      end
    end

    context "with only empty string paths" do
      let(:manifest) do
        m = Expressir::SchemaManifest.new
        m.schemas << Expressir::SchemaManifestEntry.new(id: "empty_schema",
                                                        path: "")
        m
      end
      let(:validator) { described_class.new(manifest) }

      it "returns warning for empty path" do
        warnings = validator.validate_path_completeness
        expect(warnings.size).to eq(1)
        expect(warnings.first[:schema]).to eq("empty_schema")
      end
    end
  end

  describe "#validate_referential_integrity" do
    context "when all references resolve" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/valid_references_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "returns empty error array" do
        errors = validator.validate_referential_integrity
        expect(errors).to be_empty
      end
    end

    context "when some references are unresolved" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/unresolved_references_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "returns errors for unresolved references" do
        errors = validator.validate_referential_integrity
        expect(errors).not_to be_empty
      end

      it "includes schema ID in error" do
        errors = validator.validate_referential_integrity
        error = errors.first
        expect(error[:schema]).to eq("schema_with_unresolved_use")
      end

      it "includes referenced schema name in error" do
        errors = validator.validate_referential_integrity
        error = errors.first
        expect(error[:referenced_schema]).to eq("nonexistent_schema")
      end

      it "includes interface kind (USE/REFERENCE) in error" do
        errors = validator.validate_referential_integrity
        error = errors.first
        expect(error[:interface_kind]).to eq("USE")
      end

      it "includes descriptive error message" do
        errors = validator.validate_referential_integrity
        error = errors.first
        expect(error[:message]).to include("Cannot resolve USE FROM nonexistent_schema")
        expect(error[:message]).to include("schema_with_unresolved_use")
      end
    end

    context "with schemas having no paths" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/incomplete_paths_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "skips validation for schemas without paths" do
        # Should only validate resolved_schema, which has no interfaces
        errors = validator.validate_referential_integrity
        expect(errors).to be_empty
      end
    end

    context "with schemas having missing files" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/missing_files_manifest.yaml") }
      let(:validator) { described_class.new(manifest) }

      it "skips validation for schemas with non-existent files" do
        # Should skip missing_schema since file doesn't exist
        errors = validator.validate_referential_integrity
        expect(errors).to be_empty
      end
    end

    context "when schema file cannot be parsed" do
      let(:manifest) do
        m = Expressir::SchemaManifest.new
        # Point to a non-EXPRESS file to trigger parse error
        m.schemas << Expressir::SchemaManifestEntry.new(id: "bad_schema",
                                                        path: "#{fixtures_dir}/manifest/valid_manifest.yaml")
        m
      end
      let(:validator) { described_class.new(manifest) }

      it "returns parsing error" do
        errors = validator.validate_referential_integrity
        expect(errors).not_to be_empty
      end

      it "includes schema ID and error message" do
        errors = validator.validate_referential_integrity
        error = errors.first
        expect(error[:schema]).to eq("bad_schema")
        expect(error[:message]).to include("Failed to parse schema")
      end
    end
  end

  describe "#build_schema_registry" do
    let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/valid_manifest.yaml") }
    let(:validator) { described_class.new(manifest) }

    it "creates ID to path mapping" do
      registry = validator.send(:build_schema_registry)
      expect(registry).to be_a(Hash)
      expect(registry["test_schema"]).to include("test_schema.exp")
      expect(registry["another_schema"]).to include("another_schema.exp")
    end

    context "with incomplete paths" do
      let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/incomplete_paths_manifest.yaml") }

      it "excludes schemas with empty paths" do
        registry = validator.send(:build_schema_registry)
        expect(registry).not_to have_key("empty_path_schema")
      end

      it "includes schemas with valid paths" do
        registry = validator.send(:build_schema_registry)
        expect(registry).to have_key("test_schema")
      end
    end
  end

  describe "#extract_base_dirs_from_manifest" do
    let(:manifest) { Expressir::SchemaManifest.from_file("#{fixtures_dir}/manifest/valid_manifest.yaml") }
    let(:validator) { described_class.new(manifest) }

    it "extracts unique base directories from schema paths" do
      base_dirs = validator.send(:extract_base_dirs_from_manifest)
      expect(base_dirs).to be_a(Array)
      expect(base_dirs).not_to be_empty
      # Should contain the directory where our test schemas are
      expect(base_dirs.first).to include("spec/fixtures/schemas")
    end

    context "with manifest having no valid paths" do
      let(:manifest) do
        m = Expressir::SchemaManifest.new
        m.schemas << Expressir::SchemaManifestEntry.new(id: "schema1",
                                                        path: nil)
        m.schemas << Expressir::SchemaManifestEntry.new(id: "schema2", path: "")
        m
      end

      it "returns current directory if no paths present" do
        base_dirs = validator.send(:extract_base_dirs_from_manifest)
        expect(base_dirs).to eq([Dir.pwd])
      end
    end

    context "with schemas in different directories" do
      let(:manifest) do
        m = Expressir::SchemaManifest.new
        m.schemas << Expressir::SchemaManifestEntry.new(id: "schema1",
                                                        path: "/path/to/dir1/schema1.exp")
        m.schemas << Expressir::SchemaManifestEntry.new(id: "schema2",
                                                        path: "/path/to/dir2/schema2.exp")
        m.schemas << Expressir::SchemaManifestEntry.new(id: "schema3",
                                                        path: "/path/to/dir1/schema3.exp")
        m
      end

      it "returns unique directories only" do
        base_dirs = validator.send(:extract_base_dirs_from_manifest)
        expect(base_dirs.size).to eq(2)
        expect(base_dirs).to include(File.expand_path("/path/to/dir1"))
        expect(base_dirs).to include(File.expand_path("/path/to/dir2"))
      end
    end
  end
end
