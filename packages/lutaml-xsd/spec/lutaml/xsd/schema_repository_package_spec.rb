# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::SchemaRepositoryPackage do
  let(:fixtures_path) { File.expand_path("../../fixtures", __dir__) }
  let(:urban_function_xsd) do
    File.join(fixtures_path, "i-ur/urbanFunction.xsd")
  end
  let(:urban_object_xsd) { File.join(fixtures_path, "i-ur/urbanObject.xsd") }

  describe ".create" do
    it "creates a package from a repository" do
      with_writable_temp_dir do |temp_dir|
        temp_zip = File.join(temp_dir, "test_package.zip")

        # Create repository
        repo = Lutaml::Xsd::SchemaRepository.new(
          files: [urban_function_xsd],
          namespace_mappings: [
            Lutaml::Xsd::NamespaceMapping.new(prefix: "urf", uri: "https://www.geospatial.jp/iur/urf/3.2"),
          ],
        )
        repo.parse.resolve

        # Create package configuration
        config = Lutaml::Xsd::PackageConfiguration.new(
          xsd_mode: :include_all,
          resolution_mode: :resolved,
          serialization_format: :marshal,
        )

        # Create package
        package = described_class.create(
          repository: repo,
          output_path: temp_zip,
          config: config,
          metadata: { name: "Test Package", version: "1.0" },
        )

        expect(package).to be_a(described_class)
        expect(package.zip_path).to eq(temp_zip)
        expect(File.exist?(temp_zip)).to be true
        expect(package.metadata).to include("name" => "Test Package",
                                            "version" => "1.0")
      end
    end
  end

  describe "#validate" do
    context "with a valid package" do
      it "returns successful validation result" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "valid_package.zip")

          # Create a minimal self-contained schema
          simple_schema = <<~XSD
            <?xml version="1.0" encoding="UTF-8"?>
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                       targetNamespace="http://example.com/test">
              <xs:element name="TestElement" type="xs:string"/>
            </xs:schema>
          XSD

          simple_xsd_path = File.join(temp_dir, "validation_test.xsd")
          File.write(simple_xsd_path, simple_schema)

          repo = Lutaml::Xsd::SchemaRepository.new(
            files: [simple_xsd_path],
            namespace_mappings: [
              Lutaml::Xsd::NamespaceMapping.new(prefix: "test", uri: "http://example.com/test"),
            ],
          )
          repo.parse.resolve

          # Create package configuration
          config = Lutaml::Xsd::PackageConfiguration.new(
            xsd_mode: :include_all,
            resolution_mode: :resolved,
            serialization_format: :marshal,
          )

          described_class.create(repository: repo, output_path: temp_zip,
                                 config: config)

          # Validate
          package = described_class.new(temp_zip)
          result = package.validate

          expect(result).to be_a(Lutaml::Xsd::SchemaRepositoryPackage::ValidationResult)
          expect(result.valid?).to be true
          expect(result.errors).to be_empty
        end
      end

      it "includes metadata in validation result" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "metadata_package.zip")

          simple_schema = <<~XSD
            <?xml version="1.0" encoding="UTF-8"?>
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                       targetNamespace="http://example.com/test">
              <xs:element name="TestElement" type="xs:string"/>
            </xs:schema>
          XSD

          simple_xsd_path = File.join(temp_dir, "metadata_test.xsd")
          File.write(simple_xsd_path, simple_schema)

          repo = Lutaml::Xsd::SchemaRepository.new(
            files: [simple_xsd_path],
            namespace_mappings: [
              Lutaml::Xsd::NamespaceMapping.new(prefix: "test", uri: "http://example.com/test"),
            ],
          )
          repo.parse.resolve

          # Create package configuration
          config = Lutaml::Xsd::PackageConfiguration.new(
            xsd_mode: :include_all,
            resolution_mode: :resolved,
            serialization_format: :marshal,
          )

          described_class.create(
            repository: repo,
            output_path: temp_zip,
            config: config,
            metadata: { description: "Test description" },
          )

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.metadata).to include("description" => "Test description")
          expect(result.metadata).to include("lutaml_xsd_version")
        end
      end
    end

    context "with a missing package file" do
      it "returns validation error" do
        package = described_class.new("/nonexistent/package.zip")
        result = package.validate

        expect(result.valid?).to be false
        expect(result.errors).to include(/Package file not found/)
      end
    end

    context "with invalid package structure" do
      it "detects missing metadata.yaml" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "no_metadata.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.valid?).to be false
          expect(result.errors).to include(/missing metadata\.yaml/)
        end
      end

      it "detects missing schemas directory" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "no_schemas.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({
                "files" => [],
                "namespace_mappings" => [],
                "created_at" => Time.now.iso8601,
                "lutaml_xsd_version" => Lutaml::Xsd::VERSION,
              }.to_yaml)
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.valid?).to be false
          expect(result.errors).to include(/no schemas found/)
        end
      end
    end

    context "with invalid metadata" do
      it "detects missing required fields" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "invalid_metadata.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({ "files" => [] }.to_yaml)
            end
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.valid?).to be false
          expect(result.errors).to include(/missing required field/)
        end
      end

      it "detects invalid field types" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "wrong_types.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({
                "files" => "not_an_array",
                "namespace_mappings" => [],
                "created_at" => Time.now.iso8601,
                "lutaml_xsd_version" => Lutaml::Xsd::VERSION,
              }.to_yaml)
            end
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.valid?).to be false
          expect(result.errors).to include(/must be a/)
        end
      end

      it "detects invalid namespace mappings" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "invalid_ns.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({
                "files" => [],
                "namespace_mappings" => [{ "prefix" => "gml" }], # Missing uri
                "created_at" => Time.now.iso8601,
                "lutaml_xsd_version" => Lutaml::Xsd::VERSION,
              }.to_yaml)
            end
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.valid?).to be false
          expect(result.errors).to include(/missing required fields/)
        end
      end
    end

    context "with external dependencies" do
      it "detects HTTP/HTTPS dependencies as errors" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "external_http.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({
                "files" => ["test.xsd"],
                "namespace_mappings" => [],
                "schema_location_mappings" => [
                  { "from" => "../../gml.xsd",
                    "to" => "http://example.com/gml.xsd" },
                ],
                "created_at" => Time.now.iso8601,
                "lutaml_xsd_version" => Lutaml::Xsd::VERSION,
              }.to_yaml)
            end
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.valid?).to be false
          expect(result.errors).to include(/external dependency/)
        end
      end

      it "detects absolute/relative path dependencies as warnings" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "external_path.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({
                "files" => ["test.xsd"],
                "namespace_mappings" => [],
                "schema_location_mappings" => [
                  { "from" => "gml.xsd", "to" => "/absolute/path/gml.xsd" },
                ],
                "created_at" => Time.now.iso8601,
                "lutaml_xsd_version" => Lutaml::Xsd::VERSION,
              }.to_yaml)
            end
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.warnings).to include(/may have external file dependency/)
        end
      end
    end

    context "with version compatibility" do
      it "warns about newer package versions" do
        with_writable_temp_dir do |temp_dir|
          temp_zip = File.join(temp_dir, "newer_version.zip")

          Zip::File.open(temp_zip, create: true) do |zipfile|
            zipfile.get_output_stream("metadata.yaml") do |f|
              f.write({
                "files" => [],
                "namespace_mappings" => [],
                "created_at" => Time.now.iso8601,
                "lutaml_xsd_version" => "99.99.99",
              }.to_yaml)
            end
            zipfile.get_output_stream("schemas/test.xsd") do |f|
              f.write("<schema/>")
            end
          end

          package = described_class.new(temp_zip)
          result = package.validate

          expect(result.warnings).to include(/newer lutaml-xsd/)
        end
      end
    end
  end

  describe "#load_repository" do
    it "loads a repository with correct configuration from package" do
      with_writable_temp_dir do |temp_dir|
        temp_zip = File.join(temp_dir, "load_test.zip")

        # Create a minimal schema file
        simple_schema = <<~XSD
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://example.com/test"
                     xmlns:test="http://example.com/test">
            <xs:element name="TestElement" type="xs:string"/>
          </xs:schema>
        XSD

        simple_xsd_path = File.join(temp_dir, "simple_test.xsd")
        File.write(simple_xsd_path, simple_schema)

        # Create package with simple schema
        repo = Lutaml::Xsd::SchemaRepository.new(
          files: [simple_xsd_path],
          namespace_mappings: [
            Lutaml::Xsd::NamespaceMapping.new(prefix: "test", uri: "http://example.com/test"),
          ],
        )
        repo.parse.resolve

        config = Lutaml::Xsd::PackageConfiguration.new(
          xsd_mode: :include_all,
          resolution_mode: :resolved,
          serialization_format: :marshal,
        )

        described_class.create(repository: repo, output_path: temp_zip,
                               config: config)

        # Load package - returns unparsed repository
        package = described_class.new(temp_zip)
        loaded_repo = package.load_repository

        # Verify repository structure (not parsed yet)
        expect(loaded_repo).to be_a(Lutaml::Xsd::SchemaRepository)
        expect(loaded_repo.files).not_to be_empty
        expect(loaded_repo.namespace_mappings.size).to be > 0
        expect(loaded_repo.namespace_mappings.first.prefix).to eq("test")
        expect(loaded_repo.namespace_mappings.first.uri).to eq("http://example.com/test")
      end
    end

    it "raises error for invalid package" do
      with_writable_temp_dir do |temp_dir|
        temp_zip = File.join(temp_dir, "invalid_load.zip")

        Zip::File.open(temp_zip, create: true) do |zipfile|
          zipfile.get_output_stream("invalid.txt") do |f|
            f.write("not a valid package")
          end
        end

        package = described_class.new(temp_zip)

        expect do
          package.load_repository
        end.to raise_error(Lutaml::Xsd::Error, /Invalid package/)
      end
    end
  end

  describe "#write_from_repository" do
    it "writes package with all required components" do
      with_writable_temp_dir do |temp_dir|
        temp_zip = File.join(temp_dir, "write_test.zip")

        # Create a minimal self-contained schema
        simple_schema = <<~XSD
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://example.com/write">
            <xs:element name="WriteTest" type="xs:string"/>
          </xs:schema>
        XSD

        simple_xsd_path = File.join(temp_dir, "write_test.xsd")
        File.write(simple_xsd_path, simple_schema)

        repo = Lutaml::Xsd::SchemaRepository.new(
          files: [simple_xsd_path],
          namespace_mappings: [
            Lutaml::Xsd::NamespaceMapping.new(prefix: "wt", uri: "http://example.com/write"),
          ],
        )
        repo.parse.resolve

        # Create package configuration
        config = Lutaml::Xsd::PackageConfiguration.new(
          xsd_mode: :include_all,
          resolution_mode: :resolved,
          serialization_format: :marshal,
        )

        package = described_class.new(temp_zip)
        result_path = package.write_from_repository(repo, config,
                                                    { custom: "value" })

        expect(result_path).to eq(temp_zip)
        expect(File.exist?(temp_zip)).to be true

        # On Windows, ensure file handles are fully released before re-opening
        # Force garbage collection to release any lingering file handles
        GC.start
        # Small delay to ensure OS releases file locks (Windows-specific)
        sleep 0.1 if Gem.win_platform?

        # Verify ZIP contents
        Zip::File.open(temp_zip) do |zipfile|
          expect(zipfile.find_entry("metadata.yaml")).not_to be_nil
          expect(zipfile.glob("schemas/*.xsd").size).to be > 0
        end

        expect(package.metadata).to include("custom" => "value")
      end
    end
  end

  describe "ValidationResult" do
    describe "#to_h" do
      it "converts validation result to hash" do
        result = Lutaml::Xsd::SchemaRepositoryPackage::ValidationResult.new(
          valid: true,
          errors: [],
          warnings: ["warning 1"],
          metadata: { "version" => "1.0" },
        )

        hash = result.to_h

        expect(hash).to include(
          valid?: true,
          errors: [],
          warnings: ["warning 1"],
          metadata: { "version" => "1.0" },
        )
      end
    end
  end
end
