# frozen_string_literal: true

require "spec_helper"
require "expressir/package/builder"
require "expressir/model/repository"
require "tempfile"
require "zip"

RSpec.describe Expressir::Package::Builder do
  let(:repository) do
    Expressir::Model::Repository.new.tap do |repo|
      # Add a simple schema for testing
      schema = Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        file: nil,
      )
      repo.add_schema(schema)
    end
  end

  let(:output_path) do
    File.join(Dir.tmpdir, "test_package_#{Time.now.to_i}.ler")
  end
  let(:builder) { described_class.new }

  after do
    # Windows: Force garbage collection to release file handles
    GC.start if Gem.win_platform?
    # Small delay on Windows to ensure file handles are released
    sleep 0.1 if Gem.win_platform?
    FileUtils.rm_f(output_path)
  end

  describe "#build" do
    it "creates a package file" do
      result = builder.build(repository, output_path, {
                               name: "Test Package",
                               version: "1.0.0",
                             })

      expect(File.exist?(output_path)).to be true
      expect(result).to eq(output_path)
    end

    it "creates a valid ZIP archive" do
      builder.build(repository, output_path, {
                      name: "Test Package",
                      version: "1.0.0",
                    })

      expect { Zip::File.open(output_path) }.not_to raise_error
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "includes metadata.yaml in package" do
      builder.build(repository, output_path, {
                      name: "Test Package",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        expect(metadata_entry).not_to be_nil
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "includes manifest.yaml in package" do
      builder.build(repository, output_path, {
                      name: "Test Package",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        manifest_entry = zip.find_entry("manifest.yaml")
        expect(manifest_entry).not_to be_nil
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "includes indexes in package" do
      repository.build_indexes

      builder.build(repository, output_path, {
                      name: "Test Package",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        expect(zip.find_entry("entity_index.marshal")).not_to be_nil
        expect(zip.find_entry("type_index.marshal")).not_to be_nil
        expect(zip.find_entry("reference_index.marshal")).not_to be_nil
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "uses default options when not provided" do
      builder.build(repository, output_path)

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata_content = metadata_entry.get_input_stream.read
        metadata = Expressir::Package::Metadata.from_yaml(metadata_content)

        expect(metadata.name).to eq("Unnamed Package")
        expect(metadata.version).to eq("1.0.0")
        expect(metadata.express_mode).to eq("include_all")
        expect(metadata.resolution_mode).to eq("resolved")
        expect(metadata.serialization_format).to eq("marshal")
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "raises error for invalid metadata" do
      expect do
        builder.build(repository, output_path, {
                        name: "",
                        version: "",
                      })
      end.to raise_error(ArgumentError, /Invalid metadata/)
    end
  end

  describe "serialization modes" do
    context "with marshal format" do
      it "includes repository.marshal" do
        builder.build(repository, output_path, {
                        name: "Test",
                        version: "1.0",
                        serialization_format: "marshal",
                      })

        Zip::File.open(output_path) do |zip|
          expect(zip.find_entry("repository.marshal")).not_to be_nil
        end
        # Windows: Release file handle
        GC.start if Gem.win_platform?
      end
    end

    context "with json format" do
      it "includes repository.json" do
        builder.build(repository, output_path, {
                        name: "Test",
                        version: "1.0",
                        serialization_format: "json",
                      })

        Zip::File.open(output_path) do |zip|
          expect(zip.find_entry("repository.json")).not_to be_nil
        end
        # Windows: Release file handle
        GC.start if Gem.win_platform?
      end
    end

    context "with yaml format" do
      it "includes repository.yaml" do
        builder.build(repository, output_path, {
                        name: "Test",
                        version: "1.0",
                        serialization_format: "yaml",
                      })

        Zip::File.open(output_path) do |zip|
          expect(zip.find_entry("repository.yaml")).not_to be_nil
        end
        # Windows: Release file handle
        GC.start if Gem.win_platform?
      end
    end
  end

  describe "express bundling modes" do
    context "with include_all mode" do
      it "includes EXPRESS files when schemas have file paths" do
        # Create a temporary EXPRESS file
        express_file = Tempfile.new(["test_schema", ".exp"])
        express_file.write("SCHEMA test_schema; END_SCHEMA;")
        express_file.close

        repository.schemas.first.file = express_file.path

        builder.build(repository, output_path, {
                        name: "Test",
                        version: "1.0",
                        express_mode: "include_all",
                      })

        Zip::File.open(output_path) do |zip|
          express_entries = zip.entries.select do |e|
            e.name.start_with?("express_files/")
          end
          expect(express_entries).not_to be_empty
        end

        express_file.unlink
        # Windows: Release file handle
        GC.start if Gem.win_platform?
      end

      it "skips schemas without file paths" do
        builder.build(repository, output_path, {
                        name: "Test",
                        version: "1.0",
                        express_mode: "include_all",
                      })

        Zip::File.open(output_path) do |zip|
          express_entries = zip.entries.select do |e|
            e.name.start_with?("express_files/")
          end
          expect(express_entries).to be_empty
        end
        # Windows: Release file handle
        GC.start if Gem.win_platform?
      end
    end

    context "with allow_external mode" do
      it "does not include EXPRESS files" do
        builder.build(repository, output_path, {
                        name: "Test",
                        version: "1.0",
                        express_mode: "allow_external",
                      })

        Zip::File.open(output_path) do |zip|
          express_entries = zip.entries.select do |e|
            e.name.start_with?("express_files/")
          end
          expect(express_entries).to be_empty
        end
        # Windows: Release file handle
        GC.start if Gem.win_platform?
      end
    end
  end

  describe "metadata generation" do
    it "sets package name from options" do
      builder.build(repository, output_path, {
                      name: "Custom Name",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata = Expressir::Package::Metadata.from_yaml(
          metadata_entry.get_input_stream.read,
        )
        expect(metadata.name).to eq("Custom Name")
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "sets package version from options" do
      builder.build(repository, output_path, {
                      name: "Test",
                      version: "2.5.0",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata = Expressir::Package::Metadata.from_yaml(
          metadata_entry.get_input_stream.read,
        )
        expect(metadata.version).to eq("2.5.0")
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "sets package description from options" do
      builder.build(repository, output_path, {
                      name: "Test",
                      version: "1.0.0",
                      description: "Test description",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata = Expressir::Package::Metadata.from_yaml(
          metadata_entry.get_input_stream.read,
        )
        expect(metadata.description).to eq("Test description")
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "records schema count" do
      builder.build(repository, output_path, {
                      name: "Test",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata = Expressir::Package::Metadata.from_yaml(
          metadata_entry.get_input_stream.read,
        )
        expect(metadata.schemas).to eq(1)
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "records expressir version" do
      builder.build(repository, output_path, {
                      name: "Test",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata = Expressir::Package::Metadata.from_yaml(
          metadata_entry.get_input_stream.read,
        )
        expect(metadata.expressir_version).to eq(Expressir::Version::VERSION)
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end

    it "records created_at timestamp" do
      builder.build(repository, output_path, {
                      name: "Test",
                      version: "1.0.0",
                    })

      Zip::File.open(output_path) do |zip|
        metadata_entry = zip.find_entry("metadata.yaml")
        metadata = Expressir::Package::Metadata.from_yaml(
          metadata_entry.get_input_stream.read,
        )
        expect(metadata.created_at).not_to be_nil
        expect(Time.parse(metadata.created_at)).to be_within(5).of(Time.now)
      end
      # Windows: Release file handle
      GC.start if Gem.win_platform?
    end
  end
end
