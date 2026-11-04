# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Expressir::SchemaManifest do
  let(:test_manifest_path) do
    File.expand_path("../fixtures/test_manifest.yml", __dir__)
  end
  let(:sample_schemas_path) do
    File.expand_path("../fixtures/sample_schemas.yml", __dir__)
  end

  describe ".from_file" do
    context "with a valid manifest file" do
      it "loads the manifest from file" do
        manifest = described_class.from_file(test_manifest_path)

        expect(manifest).to be_a(described_class)
        expect(manifest.schemas).to be_a(Array)
        expect(manifest.schemas.map(&:id)).to include("test_schema_1",
                                                      "test_schema_2")
      end

      it "creates SchemaManifestEntry objects for each schema" do
        manifest = described_class.from_file(test_manifest_path)

        expect(manifest.schemas).to all(be_a(Expressir::SchemaManifestEntry))
      end
    end

    context "with an invalid file" do
      it "raises an error for non-existent file" do
        expect do
          described_class.from_file("non_existent.yml")
        end.to raise_error(Expressir::ManifestValidationError)
      end
    end
  end

  describe "#initialize" do
    it "creates an empty manifest" do
      manifest = described_class.new

      expect(manifest.schemas).to eq([])
    end

    it "accepts schemas array" do
      schemas = [
        Expressir::SchemaManifestEntry.new(id: "test", path: "test.exp"),
      ]
      manifest = described_class.new(schemas: schemas)

      expect(manifest.schemas).to eq(schemas)
    end
  end

  describe "#base_path" do
    it "returns the base path of the manifest" do
      manifest = described_class.from_file(test_manifest_path)

      expect(manifest.base_path).to eq(File.dirname(test_manifest_path))
    end
  end

  describe "#to_file" do
    it "writes the manifest to a file" do
      manifest = described_class.from_file(test_manifest_path)
      temp_file = File.join(Dir.tmpdir, "test_manifest_output.yml")

      begin
        manifest.to_file(temp_file)
        expect(File.exist?(temp_file)).to be true

        # Verify the content can be read back
        reloaded = described_class.from_file(temp_file)
        expect(reloaded.schemas.map(&:id)).to eq(manifest.schemas.map(&:id))
      ensure
        FileUtils.rm_f(temp_file)
      end
    end
  end

  describe "#concat" do
    it "concatenates another manifest" do
      manifest1 = described_class.new(schemas: [
                                        Expressir::SchemaManifestEntry.new(
                                          id: "schema1", path: "path1.exp",
                                        ),
                                      ])
      manifest2 = described_class.new(schemas: [
                                        Expressir::SchemaManifestEntry.new(
                                          id: "schema2", path: "path2.exp",
                                        ),
                                      ])

      manifest1.concat(manifest2)

      expect(manifest1.schemas.length).to eq(2)
      expect(manifest1.schemas.map(&:id)).to include("schema1", "schema2")
    end

    it "raises error when concatenating non-manifest object" do
      manifest = described_class.new

      expect do
        manifest.concat("not a manifest")
      end.to raise_error(StandardError,
                         "Can only concat a SchemaManifest object.")
    end
  end

  describe "#save_to_path" do
    it "saves the manifest to a specified path" do
      # Use absolute paths to avoid path resolution issues
      test_exp_path = File.expand_path("../fixtures/test.exp", __dir__)
      manifest = described_class.new(schemas: [
                                       Expressir::SchemaManifestEntry.new(
                                         id: "test", path: test_exp_path,
                                       ),
                                     ])
      temp_file = File.expand_path("../fixtures/test_save_manifest.yml",
                                   __dir__)

      begin
        manifest.save_to_path(temp_file)
        expect(File.exist?(temp_file)).to be true

        # Verify the content
        content = File.read(temp_file)
        expect(content).to include("schemas:")
        expect(content).to include("test:")
      ensure
        FileUtils.rm_f(temp_file)
      end
    end
  end
end
