# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/package_metadata"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::PackageMetadata do
  let(:config_yaml) do
    <<~YAML
      packages:
        "ModelRoot::i-UR::uro":
          xmlns: "http://www.kantei.go.jp/jp/singi/tiiki/toshisaisei/itoshisaisei/iur/uro/2.0"
          targetNamespace: "http://www.kantei.go.jp/jp/singi/tiiki/toshisaisei/itoshisaisei/iur/uro/2.0"
          schemaLocation: "../../schemas/uro/2.0/urbanObject.xsd"
          prefix: "uro"
          documentation: "Urban Object package"

        "ModelRoot::CityGML2.0::Core":
          xmlns: "http://www.opengis.net/citygml/2.0"
          targetNamespace: "http://www.opengis.net/citygml/2.0/core"
          prefix: "core"
          documentation: "CityGML 2.0 Core module"

        "ModelRoot::CityGML2.0::*":
          xmlns: "http://www.opengis.net/citygml/2.0"
          prefix: "citygml"

        "ModelRoot::*::Nested":
          documentation: "Nested package pattern"
          version: "1.0"
    YAML
  end

  let(:config_file) do
    file = Tempfile.new(["package_metadata", ".yml"])
    file.write(config_yaml)
    file.close
    file
  end

  after do
    config_file.unlink if config_file
  end

  describe "#initialize" do
    context "with valid configuration file" do
      it "loads configuration successfully" do
        metadata = described_class.new(config_file.path)
        expect(metadata.config).to be_a(Hash)
        expect(metadata.config["packages"]).to be_a(Hash)
      end

      it "loads all package entries" do
        metadata = described_class.new(config_file.path)
        packages = metadata.config["packages"]
        expect(packages.keys).to include(
          "ModelRoot::i-UR::uro",
          "ModelRoot::CityGML2.0::Core",
          "ModelRoot::CityGML2.0::*",
          "ModelRoot::*::Nested"
        )
      end
    end

    context "with nil config path" do
      it "creates empty configuration" do
        metadata = described_class.new(nil)
        expect(metadata.config).to eq({ "packages" => {} })
      end
    end

    context "with non-existent file" do
      it "raises Errno::ENOENT" do
        expect do
          described_class.new("/nonexistent/path/config.yml")
        end.to raise_error(Errno::ENOENT, /Configuration file not found/)
      end
    end

    context "with invalid YAML" do
      let(:invalid_yaml_file) do
        file = Tempfile.new(["invalid", ".yml"])
        file.write("invalid: yaml: content: [")
        file.close
        file
      end

      after do
        invalid_yaml_file.unlink
      end

      it "raises Psych::SyntaxError" do
        expect do
          described_class.new(invalid_yaml_file.path)
        end.to raise_error(Psych::SyntaxError, /Invalid YAML syntax/)
      end
    end

    context "with invalid configuration format" do
      let(:invalid_format_file) do
        file = Tempfile.new(["invalid_format", ".yml"])
        file.write("not_packages: {}")
        file.close
        file
      end

      after do
        invalid_format_file.unlink
      end

      it "raises ArgumentError" do
        expect do
          described_class.new(invalid_format_file.path)
        end.to raise_error(ArgumentError, /Invalid configuration format/)
      end
    end
  end

  describe "#metadata_for" do
    let(:metadata) { described_class.new(config_file.path) }

    context "with exact package path match" do
      it "returns complete metadata hash" do
        result = metadata.metadata_for("ModelRoot::i-UR::uro")
        expect(result).to be_a(Hash)
        expect(result[:xmlns]).to eq("http://www.kantei.go.jp/jp/singi/tiiki/toshisaisei/itoshisaisei/iur/uro/2.0")
        expect(result[:targetNamespace]).to eq("http://www.kantei.go.jp/jp/singi/tiiki/toshisaisei/itoshisaisei/iur/uro/2.0")
        expect(result[:schemaLocation]).to eq("../../schemas/uro/2.0/urbanObject.xsd")
        expect(result[:prefix]).to eq("uro")
        expect(result[:documentation]).to eq("Urban Object package")
      end

      it "returns metadata with symbol keys" do
        result = metadata.metadata_for("ModelRoot::CityGML2.0::Core")
        expect(result.keys).to all(be_a(Symbol))
      end
    end

    context "with wildcard pattern match" do
      it "matches single-level wildcard" do
        result = metadata.metadata_for("ModelRoot::CityGML2.0::Building")
        expect(result[:xmlns]).to eq("http://www.opengis.net/citygml/2.0")
        expect(result[:prefix]).to eq("citygml")
      end

      it "matches multi-level wildcard" do
        result = metadata.metadata_for("ModelRoot::Intermediate::Nested")
        expect(result[:documentation]).to eq("Nested package pattern")
        expect(result[:version]).to eq("1.0")
      end

      it "does not match incorrect wildcard patterns" do
        result = metadata.metadata_for("ModelRoot::CityGML2.0::Core::Sub")
        # Should not match "ModelRoot::CityGML2.0::*" which is single-level
        # And no exact match exists for this path
        expect(result[:prefix]).to be_nil
      end
    end

    context "with merged metadata from multiple matches" do
      it "merges exact match and wildcard match" do
        result = metadata.metadata_for("ModelRoot::CityGML2.0::Core")
        # Should have data from both exact match and wildcard
        expect(result[:xmlns]).to eq("http://www.opengis.net/citygml/2.0")
        expect(result[:prefix]).to eq("core") # Exact match overrides wildcard
        expect(result[:targetNamespace]).to eq("http://www.opengis.net/citygml/2.0/core")
      end
    end

    context "with no matching package path" do
      it "returns empty hash" do
        result = metadata.metadata_for("NonExistent::Package::Path")
        expect(result).to eq({})
      end
    end

    context "with nil package path" do
      it "returns empty hash" do
        result = metadata.metadata_for(nil)
        expect(result).to eq({})
      end
    end

    context "with caching" do
      it "caches results for repeated queries" do
        first_result = metadata.metadata_for("ModelRoot::i-UR::uro")
        second_result = metadata.metadata_for("ModelRoot::i-UR::uro")

        expect(second_result).to equal(first_result) # Same object reference
      end

      it "clears cache when requested" do
        first_result = metadata.metadata_for("ModelRoot::i-UR::uro")
        metadata.clear_cache
        second_result = metadata.metadata_for("ModelRoot::i-UR::uro")

        expect(second_result).not_to equal(first_result) # Different object
        expect(second_result).to eq(first_result) # But same content
      end
    end
  end

  describe "#xmlns_for" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns xmlns for exact match" do
      xmlns = metadata.xmlns_for("ModelRoot::i-UR::uro")
      expect(xmlns).to eq("http://www.kantei.go.jp/jp/singi/tiiki/toshisaisei/itoshisaisei/iur/uro/2.0")
    end

    it "returns xmlns for wildcard match" do
      xmlns = metadata.xmlns_for("ModelRoot::CityGML2.0::Transportation")
      expect(xmlns).to eq("http://www.opengis.net/citygml/2.0")
    end

    it "returns nil for non-existent package" do
      xmlns = metadata.xmlns_for("NonExistent::Package")
      expect(xmlns).to be_nil
    end
  end

  describe "#target_namespace_for" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns target namespace when available" do
      ns = metadata.target_namespace_for("ModelRoot::i-UR::uro")
      expect(ns).to eq("http://www.kantei.go.jp/jp/singi/tiiki/toshisaisei/itoshisaisei/iur/uro/2.0")
    end

    it "returns nil when not available" do
      ns = metadata.target_namespace_for("ModelRoot::CityGML2.0::Building")
      expect(ns).to be_nil
    end
  end

  describe "#schema_location_for" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns schema location when available" do
      location = metadata.schema_location_for("ModelRoot::i-UR::uro")
      expect(location).to eq("../../schemas/uro/2.0/urbanObject.xsd")
    end

    it "returns nil when not available" do
      location = metadata.schema_location_for("ModelRoot::CityGML2.0::Core")
      expect(location).to be_nil
    end
  end

  describe "#prefix_for" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns prefix for exact match" do
      prefix = metadata.prefix_for("ModelRoot::i-UR::uro")
      expect(prefix).to eq("uro")
    end

    it "returns prefix for wildcard match" do
      prefix = metadata.prefix_for("ModelRoot::CityGML2.0::Vegetation")
      expect(prefix).to eq("citygml")
    end

    it "returns nil for non-existent package" do
      prefix = metadata.prefix_for("NonExistent::Package")
      expect(prefix).to be_nil
    end
  end

  describe "#documentation_for" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns documentation when available" do
      doc = metadata.documentation_for("ModelRoot::i-UR::uro")
      expect(doc).to eq("Urban Object package")
    end

    it "returns documentation for wildcard match" do
      doc = metadata.documentation_for("ModelRoot::Anything::Nested")
      expect(doc).to eq("Nested package pattern")
    end

    it "returns nil when not available" do
      doc = metadata.documentation_for("NonExistent::Package")
      expect(doc).to be_nil
    end
  end

  describe "#has_metadata?" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns true for package with metadata" do
      expect(metadata.has_metadata?("ModelRoot::i-UR::uro")).to be true
    end

    it "returns true for wildcard match" do
      expect(metadata.has_metadata?("ModelRoot::CityGML2.0::Building")).to be true
    end

    it "returns false for package without metadata" do
      expect(metadata.has_metadata?("NonExistent::Package")).to be false
    end
  end

  describe "#package_paths" do
    let(:metadata) { described_class.new(config_file.path) }

    it "returns all configured package path patterns" do
      paths = metadata.package_paths
      expect(paths).to be_an(Array)
      expect(paths).to include(
        "ModelRoot::i-UR::uro",
        "ModelRoot::CityGML2.0::Core",
        "ModelRoot::CityGML2.0::*",
        "ModelRoot::*::Nested"
      )
    end

    it "includes wildcard patterns" do
      paths = metadata.package_paths
      wildcard_patterns = paths.select { |p| p.include?("*") }
      expect(wildcard_patterns).not_to be_empty
    end
  end

  describe "#clear_cache" do
    let(:metadata) { described_class.new(config_file.path) }

    it "clears the internal cache" do
      # Populate cache
      metadata.metadata_for("ModelRoot::i-UR::uro")
      expect(metadata.instance_variable_get(:@cache)).not_to be_empty

      # Clear cache
      metadata.clear_cache
      expect(metadata.instance_variable_get(:@cache)).to be_empty
    end
  end

  describe "wildcard pattern matching" do
    let(:metadata) { described_class.new(config_file.path) }

    context "with single-level wildcard" do
      it "matches direct children" do
        expect(metadata.has_metadata?("ModelRoot::CityGML2.0::Building")).to be true
        expect(metadata.has_metadata?("ModelRoot::CityGML2.0::Transportation")).to be true
        expect(metadata.has_metadata?("ModelRoot::CityGML2.0::Vegetation")).to be true
      end

      it "does not match grandchildren" do
        # "ModelRoot::CityGML2.0::*" should not match deeper nesting
        result = metadata.metadata_for("ModelRoot::CityGML2.0::Building::Detail")
        # Should only get exact matches, not wildcard
        expect(result[:prefix]).to be_nil
      end
    end

    context "with multi-level wildcard" do
      it "matches with any intermediate package" do
        expect(metadata.has_metadata?("ModelRoot::A::Nested")).to be true
        expect(metadata.has_metadata?("ModelRoot::B::Nested")).to be true
        expect(metadata.has_metadata?("ModelRoot::CityGML2.0::Nested")).to be true
      end

      it "requires exact component match" do
        expect(metadata.has_metadata?("ModelRoot::Intermediate::NotNested")).to be false
      end
    end
  end

  describe "edge cases" do
    context "with empty configuration" do
      let(:metadata) { described_class.new(nil) }

      it "returns empty results for any query" do
        expect(metadata.metadata_for("Any::Package")).to eq({})
        expect(metadata.xmlns_for("Any::Package")).to be_nil
        expect(metadata.has_metadata?("Any::Package")).to be false
        expect(metadata.package_paths).to be_empty
      end
    end

    context "with package paths containing special characters" do
      let(:special_config) do
        file = Tempfile.new(["special", ".yml"])
        file.write(<<~YAML)
          packages:
            "Root::Package-Name::Sub.Package":
              prefix: "special"
        YAML
        file.close
        file
      end

      after do
        special_config.unlink
      end

      it "handles special characters correctly" do
        metadata = described_class.new(special_config.path)
        expect(metadata.prefix_for("Root::Package-Name::Sub.Package")).to eq("special")
      end
    end

    context "with deeply nested package paths" do
      let(:deep_config) do
        file = Tempfile.new(["deep", ".yml"])
        file.write(<<~YAML)
          packages:
            "Level1::Level2::Level3::Level4::Level5":
              prefix: "deep"
        YAML
        file.close
        file
      end

      after do
        deep_config.unlink
      end

      it "handles deep nesting correctly" do
        metadata = described_class.new(deep_config.path)
        expect(metadata.prefix_for("Level1::Level2::Level3::Level4::Level5")).to eq("deep")
      end
    end
  end
end