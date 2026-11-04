# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Lutaml::Xsd::SchemaRepository, "smart loading" do
  let(:xsd_fixture_path) do
    File.expand_path("../../fixtures/metaschema.xsd", __dir__)
  end

  let(:temp_dir) do
    dir = File.join(Dir.pwd, "tmp_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(dir)
    dir
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".from_file" do
    context "with .xsd file" do
      it "loads and parses XSD file successfully" do
        repository = described_class.from_file(xsd_fixture_path)

        expect(repository).to be_a(described_class)
        expect(repository.instance_variable_get(:@resolved)).to be true
        expect(repository.instance_variable_get(:@parsed_schemas).size).to be > 0
      end

      it "creates a repository with correct file path" do
        repository = described_class.from_file(xsd_fixture_path)

        expect(repository.files).to include(File.expand_path(xsd_fixture_path))
      end

      it "returns a resolved repository" do
        repository = described_class.from_file(xsd_fixture_path)
        stats = repository.statistics

        expect(stats[:resolved]).to be true
        expect(stats[:total_types]).to be > 0
      end
    end

    context "with .yml file" do
      let(:yaml_config_path) { File.join(temp_dir, "test_config.yml") }

      before do
        yaml_content = <<~YAML
          files:
            - #{xsd_fixture_path}
          namespace_mappings:
            - prefix: "xs"
              uri: "http://www.w3.org/2001/XMLSchema"
        YAML
        File.write(yaml_config_path, yaml_content)
      end

      it "loads repository from YAML configuration" do
        repository = described_class.from_file(yaml_config_path)

        expect(repository).to be_a(described_class)
        expect(repository.files).to include(xsd_fixture_path)
      end

      it "applies namespace mappings from YAML" do
        repository = described_class.from_file(yaml_config_path)

        expect(repository.namespace_mappings).not_to be_empty
        expect(repository.namespace_mappings.first.prefix).to eq("xs")
      end
    end

    context "with .yaml file extension" do
      let(:yaml_config_path) { File.join(temp_dir, "test_config.yaml") }

      before do
        yaml_content = <<~YAML
          files:
            - #{xsd_fixture_path}
        YAML
        File.write(yaml_config_path, yaml_content)
      end

      it "handles .yaml extension correctly" do
        repository = described_class.from_file(yaml_config_path)

        expect(repository).to be_a(described_class)
        expect(repository.files).to include(xsd_fixture_path)
      end
    end

    context "with .lxr package file" do
      let(:lxr_package_path) { File.join(temp_dir, "test_package.lxr") }

      before do
        # Create a package first
        repository = described_class.new(files: [xsd_fixture_path])
        repository.parse.resolve
        repository.to_package(
          lxr_package_path,
          xsd_mode: :include_all,
          resolution_mode: :resolved,
          serialization_format: :marshal,
        )
      end

      it "loads repository from LXR package" do
        repository = described_class.from_file(lxr_package_path)

        expect(repository).to be_a(described_class)
        stats = repository.statistics
        expect(stats[:total_types]).to be > 0
      end

      it "returns a resolved repository from package" do
        repository = described_class.from_file(lxr_package_path)

        expect(repository.statistics[:resolved]).to be true
      end
    end

    context "with unsupported file type" do
      let(:unsupported_file) { File.join(temp_dir, "test.txt") }

      before do
        File.write(unsupported_file, "some content")
      end

      it "raises ConfigurationError for unsupported extension" do
        expect do
          described_class.from_file(unsupported_file)
        end.to raise_error(
          Lutaml::Xsd::ConfigurationError,
          /Unsupported file type.*Expected \.xsd, \.rng, \.rnc, \.lxr, \.yml, or \.yaml/,
        )
      end
    end

    context "with non-existent file" do
      it "raises an error for missing XSD file" do
        expect do
          described_class.from_file("/nonexistent/file.xsd")
        end.to raise_error(Errno::ENOENT)
      end

      it "raises an error for missing YAML file" do
        expect do
          described_class.from_file("/nonexistent/config.yml")
        end.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe ".from_file_cached" do
    let(:source_xsd) { File.join(temp_dir, "source.xsd") }
    let(:cache_lxr) { File.join(temp_dir, "source.lxr") }

    # Create a simple self-contained XSD for caching tests
    let(:simple_xsd_content) do
      <<~XSD
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="http://example.com/test"
                   xmlns:test="http://example.com/test">
          <xs:complexType name="PersonType">
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
              <xs:element name="age" type="xs:integer"/>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="Person" type="test:PersonType"/>
        </xs:schema>
      XSD
    end

    before do
      # Write simple self-contained XSD for testing
      File.write(source_xsd, simple_xsd_content)
    end

    context "when cache does not exist" do
      it "creates cache and returns repository" do
        expect(File.exist?(cache_lxr)).to be false

        repository = described_class.from_file_cached(source_xsd)

        expect(repository).to be_a(described_class)
        expect(File.exist?(cache_lxr)).to be true
      end

      it "creates a valid LXR package" do
        described_class.from_file_cached(source_xsd)

        # Verify the package is valid
        validation = Lutaml::Xsd::SchemaRepositoryPackage.new(cache_lxr).validate
        expect(validation.valid?).to be true
      end
    end

    context "when cache exists and is fresh" do
      before do
        # Create initial cache
        repository = described_class.new(files: [source_xsd])
        repository.parse.resolve
        repository.to_package(
          cache_lxr,
          xsd_mode: :include_all,
          resolution_mode: :resolved,
          serialization_format: :marshal,
        )

        # Ensure cache is newer
        FileUtils.touch(cache_lxr, mtime: Time.now + 1)
      end

      it "uses cached package without rebuilding" do
        original_mtime = File.mtime(cache_lxr)

        repository = described_class.from_file_cached(source_xsd)

        expect(repository).to be_a(described_class)
        expect(File.mtime(cache_lxr)).to eq(original_mtime)
      end

      it "loads repository from cache efficiently" do
        repository = described_class.from_file_cached(source_xsd)

        expect(repository.statistics[:total_types]).to be > 0
      end
    end

    context "when cache exists but is stale" do
      before do
        # Create initial cache
        repository = described_class.new(files: [source_xsd])
        repository.parse.resolve
        repository.to_package(
          cache_lxr,
          xsd_mode: :include_all,
          resolution_mode: :resolved,
          serialization_format: :marshal,
        )

        # Make source newer than cache
        sleep 0.1 # Ensure time difference
        FileUtils.touch(source_xsd)
      end

      it "rebuilds cache when source is newer" do
        original_mtime = File.mtime(cache_lxr)
        sleep 0.1 # Ensure new mtime will be different

        repository = described_class.from_file_cached(source_xsd)

        expect(repository).to be_a(described_class)
        expect(File.mtime(cache_lxr)).to be > original_mtime
      end

      it "creates fresh package with updated timestamp" do
        described_class.from_file_cached(source_xsd)

        expect(File.mtime(cache_lxr)).to be >= File.mtime(source_xsd)
      end
    end

    context "with custom cache path" do
      let(:custom_cache) { File.join(temp_dir, "custom_cache.lxr") }

      it "uses custom cache path when specified" do
        repository = described_class.from_file_cached(
          source_xsd,
          lxr_path: custom_cache,
        )

        expect(repository).to be_a(described_class)
        expect(File.exist?(custom_cache)).to be true
        expect(File.exist?(cache_lxr)).to be false
      end
    end

    context "with YAML source file" do
      let(:source_yaml) { File.join(temp_dir, "source.yml") }
      let(:yaml_cache) { File.join(temp_dir, "source.lxr") }

      before do
        yaml_content = <<~YAML
          files:
            - #{xsd_fixture_path}
        YAML
        File.write(source_yaml, yaml_content)
      end

      it "creates cache from YAML configuration" do
        repository = described_class.from_file_cached(source_yaml)

        expect(repository).to be_a(described_class)
        expect(File.exist?(yaml_cache)).to be true
      end

      it "rebuilds when YAML is modified" do
        # Create initial cache
        described_class.from_file_cached(source_yaml)
        original_mtime = File.mtime(yaml_cache)

        # Modify YAML
        sleep 0.1
        File.write(source_yaml, "#{File.read(source_yaml)}\n# comment")

        # Load again
        sleep 0.1
        described_class.from_file_cached(source_yaml)

        expect(File.mtime(yaml_cache)).to be > original_mtime
      end
    end

    context "integration with from_file" do
      it "produces equivalent repositories" do
        repo_direct = described_class.from_file(source_xsd)
        repo_cached = described_class.from_file_cached(source_xsd)

        expect(repo_direct.statistics[:total_types]).to eq(
          repo_cached.statistics[:total_types],
        )
        expect(repo_direct.all_namespaces.sort).to eq(
          repo_cached.all_namespaces.sort,
        )
      end
    end
  end

  describe "cache behavior validation" do
    let(:source_xsd) { File.join(temp_dir, "source.xsd") }
    let(:cache_lxr) { File.join(temp_dir, "source.lxr") }

    # Create a simple self-contained XSD for validation tests
    let(:simple_xsd_content) do
      <<~XSD
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="http://example.com/validation"
                   xmlns:val="http://example.com/validation">
          <xs:complexType name="TestType">
            <xs:sequence>
              <xs:element name="field" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
          <xs:element name="TestElement" type="val:TestType"/>
        </xs:schema>
      XSD
    end

    before do
      File.write(source_xsd, simple_xsd_content)
    end

    it "cache contains all necessary data" do
      described_class.from_file_cached(source_xsd)

      # Load from cache using from_file which handles resolution
      cached_repo = described_class.from_file(cache_lxr)

      expect(cached_repo.statistics[:total_types]).to be > 0
      expect(cached_repo.all_namespaces).not_to be_empty
    end

    it "cached repository is immediately usable" do
      described_class.from_file_cached(source_xsd)

      # Load and use without additional parsing using from_file
      cached_repo = described_class.from_file(cache_lxr)

      # Should be able to find types immediately
      all_types = cached_repo.all_type_names
      expect(all_types).not_to be_empty

      # Try to find a type
      unless all_types.empty?
        result = cached_repo.find_type(all_types.first)
        expect(result).to be_a(Lutaml::Xsd::TypeResolutionResult)
      end
    end
  end
end
