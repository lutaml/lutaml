# frozen_string_literal: true

require "spec_helper"
require "expressir/package/reader"
require "expressir/package/builder"
require "expressir/model/repository"
require "tempfile"
require "zip"

RSpec.describe Expressir::Package::Reader do
  let(:repository) do
    schema = Expressir::Model::Declarations::Schema.new(
      id: "test_schema",
      file: nil,
    )
    Expressir::Model::Repository.new(schemas: [schema]).tap(&:build_indexes)
  end

  let(:package_path) do
    # Use Tempfile.create for cross-platform compatibility (especially Windows)
    # Tempfile.create properly handles file permissions on Windows
    file = Tempfile.create(["test_package_", ".ler"])
    path = file.path
    file.close
    path
  end
  let(:builder) { Expressir::Package::Builder.new }
  let(:reader) { described_class.new }

  after do
    # Windows: Force garbage collection to release file handles
    GC.start if Gem.win_platform?
    # Small delay on Windows to ensure file handles are released
    sleep 0.1 if Gem.win_platform?
    FileUtils.rm_f(package_path)
  end

  describe ".load" do
    it "loads a package using class method" do
      builder.build(repository, package_path, {
                      name: "Test Package",
                      version: "1.0.0",
                    })

      loaded_repo = described_class.load(package_path)
      expect(loaded_repo).to be_a(Expressir::Model::Repository)
    end
  end

  describe "#load" do
    context "with valid package" do
      before do
        builder.build(repository, package_path, {
                        name: "Test Package",
                        version: "1.0.0",
                      })
      end

      it "loads repository from package" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo).to be_a(Expressir::Model::Repository)
      end

      it "restores schemas" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo.schemas.size).to eq(1)
        expect(loaded_repo.schemas.first.id).to eq("test_schema")
      end

      it "restores entity index" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo.entity_index).not_to be_nil
      end

      it "restores type index" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo.type_index).not_to be_nil
      end

      it "restores reference index" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo.reference_index).not_to be_nil
      end
    end

    context "with non-existent package" do
      it "raises ArgumentError" do
        expect do
          reader.load("/non/existent/package.ler")
        end.to raise_error(ArgumentError, /not found/)
      end
    end

    context "with missing metadata" do
      it "raises error" do
        # Create a ZIP without metadata
        Zip::File.open(package_path, create: true) do |zip|
          zip.get_output_stream("dummy.txt") { |s| s.write("test") }
        end

        expect do
          reader.load(package_path)
        end.to raise_error(/Metadata not found/)
      end
    end
  end

  describe "serialization format support" do
    context "with marshal format" do
      before do
        builder.build(repository, package_path, {
                        name: "Test",
                        version: "1.0",
                        serialization_format: "marshal",
                      })
      end

      it "loads repository from marshal" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo).to be_a(Expressir::Model::Repository)
        expect(loaded_repo.schemas.size).to eq(1)
      end
    end

    context "with json format" do
      before do
        builder.build(repository, package_path, {
                        name: "Test",
                        version: "1.0",
                        serialization_format: "json",
                      })
      end

      it "loads repository from json" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo).to be_a(Expressir::Model::Repository)
      end
    end

    context "with yaml format" do
      before do
        builder.build(repository, package_path, {
                        name: "Test",
                        version: "1.0",
                        serialization_format: "yaml",
                      })
      end

      it "loads repository from yaml" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo).to be_a(Expressir::Model::Repository)
      end
    end
  end

  describe "resolution mode support" do
    context "with resolved mode" do
      before do
        builder.build(repository, package_path, {
                        name: "Test",
                        version: "1.0",
                        resolution_mode: "resolved",
                      })
      end

      it "loads from serialized repository" do
        loaded_repo = reader.load(package_path)
        expect(loaded_repo.schemas.size).to eq(1)
      end
    end

    context "with bare mode and EXPRESS files" do
      it "parses EXPRESS files when present" do
        # Create a package with EXPRESS files
        Zip::File.open(package_path, create: true) do |zip|
          # Add metadata
          metadata = Expressir::Package::Metadata.new(
            name: "Test",
            version: "1.0",
            resolution_mode: "bare",
            schemas: 1,
            files: 1,
          )
          zip.get_output_stream("metadata.yaml") do |s|
            s.write(metadata.to_yaml)
          end

          # Add EXPRESS file
          express_content = "SCHEMA test_schema;\nEND_SCHEMA;"
          zip.get_output_stream("express_files/test_schema.exp") do |s|
            s.write(express_content)
          end

          # Add manifest
          manifest = Expressir::SchemaManifest.new
          manifest.schemas << Expressir::SchemaManifestEntry.new(
            id: "test_schema",
            path: "test_schema.exp",
          )
          zip.get_output_stream("manifest.yaml") do |s|
            s.write(manifest.to_yaml)
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
        end

        loaded_repo = reader.load(package_path)
        expect(loaded_repo).to be_a(Expressir::Model::Repository)
      end
    end
  end

  describe "index restoration" do
    before do
      builder.build(repository, package_path, {
                      name: "Test",
                      version: "1.0",
                    })
    end

    it "restores all three indexes" do
      loaded_repo = reader.load(package_path)

      expect(loaded_repo.instance_variable_get(:@entity_index)).not_to be_nil
      expect(loaded_repo.instance_variable_get(:@type_index)).not_to be_nil
      expect(loaded_repo.instance_variable_get(:@reference_index)).not_to be_nil
    end

    it "makes indexes accessible through repository" do
      loaded_repo = reader.load(package_path)

      expect(loaded_repo.entity_index).not_to be_nil
      expect(loaded_repo.type_index).not_to be_nil
      expect(loaded_repo.reference_index).not_to be_nil
    end
  end

  describe "round-trip integrity" do
    it "preserves repository structure through save and load" do
      # Build and save
      builder.build(repository, package_path, {
                      name: "Round Trip Test",
                      version: "1.0.0",
                      description: "Testing round trip",
                    })

      # Load
      loaded_repo = reader.load(package_path)

      # Verify structure
      expect(loaded_repo.schemas.size).to eq(repository.schemas.size)
      expect(loaded_repo.schemas.first.id).to eq(repository.schemas.first.id)
    end

    it "preserves marshal format" do
      test_path = package_path.sub(".ler", "_marshal.ler")

      builder.build(repository, test_path, {
                      name: "Test",
                      version: "1.0",
                      serialization_format: "marshal",
                    })

      loaded_repo = reader.load(test_path)
      expect(loaded_repo.schemas.size).to eq(1)

      # Windows: Force garbage collection before cleanup
      GC.start if Gem.win_platform?
      sleep 0.1 if Gem.win_platform?
      FileUtils.rm_f(test_path)
    end

    it "preserves json format" do
      test_path = package_path.sub(".ler", "_json.ler")

      builder.build(repository, test_path, {
                      name: "Test",
                      version: "1.0",
                      serialization_format: "json",
                    })

      loaded_repo = reader.load(test_path)
      expect(loaded_repo.schemas.size).to eq(1)

      # Windows: Force garbage collection before cleanup
      GC.start if Gem.win_platform?
      sleep 0.1 if Gem.win_platform?
      FileUtils.rm_f(test_path)
    end

    it "preserves yaml format" do
      test_path = package_path.sub(".ler", "_yaml.ler")

      builder.build(repository, test_path, {
                      name: "Test",
                      version: "1.0",
                      serialization_format: "yaml",
                    })

      loaded_repo = reader.load(test_path)
      expect(loaded_repo.schemas.size).to eq(1)

      # Windows: Force garbage collection before cleanup
      GC.start if Gem.win_platform?
      sleep 0.1 if Gem.win_platform?
      FileUtils.rm_f(test_path)
    end
  end

  describe "error handling" do
    it "handles missing serialized repository gracefully" do
      # Create package without serialized repository
      Zip::File.open(package_path, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(
          name: "Test",
          version: "1.0",
          resolution_mode: "resolved",
          serialization_format: "marshal",
          schemas: 0,
          files: 0,
        )
        zip.get_output_stream("metadata.yaml") do |s|
          s.write(metadata.to_yaml)
        end
      end

      expect do
        reader.load(package_path)
      end.to raise_error(/Serialized repository not found/)
    end

    it "handles unknown serialization format" do
      Zip::File.open(package_path, create: true) do |zip|
        metadata = Expressir::Package::Metadata.new(
          name: "Test",
          version: "1.0",
          resolution_mode: "resolved",
          serialization_format: "unknown",
          schemas: 0,
          files: 0,
        )
        zip.get_output_stream("metadata.yaml") do |s|
          s.write(metadata.to_yaml)
        end
      end

      expect do
        reader.load(package_path)
      end.to raise_error(/Unknown serialization format/)
    end
  end
end
