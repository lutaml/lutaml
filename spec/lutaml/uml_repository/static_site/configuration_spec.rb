# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/static_site/configuration"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::StaticSite::Configuration do
  describe ".load" do
    context "with default configuration file" do
      it "loads configuration from default path" do
        config = described_class.load

        expect(config).to be_a(described_class)
        expect(config.version).to eq("1.0")
      end

      it "parses all configuration sections" do
        config = described_class.load

        expect(config.output).to be_a(described_class::OutputConfig)
        expect(config.search).to be_a(described_class::SearchConfig)
        expect(config.ui).to be_a(described_class::UIConfig)
      end
    end

    context "with custom configuration file" do
      let(:custom_config_content) do
        <<~YAML
          version: "2.0"
          description: "Custom test configuration"

          output:
            modes:
              single_file:
                enabled: true
                default_filename: "custom.html"
                embed_data: true
                minify: true

          search:
            enabled: true
            fields:
              - name: "name"
                boost: 15
                searchable: true
            document_types:
              - type: "class"
                boost: 2.0
                enabled: true
            stop_words: ["test", "example"]
            pipeline: ["stemmer"]

          ui:
            title: "Custom UML Browser"
            description: "Test browser"
        YAML
      end

      let(:custom_config_file) do
        file = Tempfile.new(["custom_config", ".yml"])
        file.write(custom_config_content)
        file.close
        file
      end

      after { custom_config_file.unlink }

      it "loads custom configuration from file" do
        config = described_class.load(custom_config_file.path)

        expect(config.version).to eq("2.0")
        expect(config.description).to eq("Custom test configuration")
      end

      it "parses search field configurations" do
        config = described_class.load(custom_config_file.path)

        expect(config.search.fields).to be_an(Array)
        expect(config.search.fields.first).to be_a(described_class::SearchField)
        expect(config.search.fields.first.name).to eq("name")
        expect(config.search.fields.first.boost).to eq(15)
      end

      it "parses document type configurations" do
        config = described_class.load(custom_config_file.path)

        expect(config.search.document_types).to be_an(Array)
        expect(config.search.document_types.first).to be_a(described_class::DocumentType)
        expect(config.search.document_types.first.type).to eq("class")
        expect(config.search.document_types.first.boost).to eq(2.0)
      end
    end

    context "when configuration file doesn't exist" do
      it "creates default configuration" do
        config = described_class.load("nonexistent.yml")

        expect(config).to be_a(described_class)
        expect(config.version).to eq("1.0")
      end
    end
  end

  describe ".default_config_path" do
    it "returns path to default configuration file" do
      path = described_class.default_config_path

      expect(path).to include("config/static_site.yml")
      expect(path).to match(/\.yml$/)
    end
  end

  describe ".create_default_configuration" do
    it "creates valid default configuration" do
      config = described_class.create_default_configuration

      expect(config).to be_a(described_class)
      expect(config.version).to eq("1.0")
      expect(config.description).to include("Default")
    end
  end

  describe "#transformation_options" do
    let(:config) { described_class.load }

    it "returns transformation options as hash" do
      options = config.transformation_options

      expect(options).to be_a(Hash)
    end

    it "caches transformation options" do
      options1 = config.transformation_options
      options2 = config.transformation_options

      expect(options1).to be(options2) # Same object
    end
  end

  describe "#feature_flags" do
    let(:config) { described_class.load }

    it "returns feature flags as hash" do
      flags = config.feature_flags

      expect(flags).to be_a(Hash)
    end

    it "caches feature flags" do
      flags1 = config.feature_flags
      flags2 = config.feature_flags

      expect(flags1).to be(flags2)
    end
  end

  describe "#feature_enabled?" do
    let(:config) { described_class.load }

    it "checks if feature is enabled" do
      # Debug: check what features actually contains
      flags = config.feature_flags

      # The YAML config has search: true under features
      expect(config.feature_enabled?("search")).to be true
    end

    it "accepts symbol arguments" do
      expect(config.feature_enabled?(:search)).to be true
    end

    it "returns false for disabled features" do
      expect(config.feature_enabled?("nonexistent_feature")).to be false
    end
  end

  describe "OutputMode" do
    let(:output_mode) { described_class::OutputMode.new }

    it "has sensible defaults" do
      expect(output_mode.enabled).to be true
      expect(output_mode.minify).to be false
    end

    it "can be configured" do
      output_mode.enabled = false
      output_mode.default_filename = "test.html"
      output_mode.minify = true

      expect(output_mode.enabled).to be false
      expect(output_mode.default_filename).to eq("test.html")
      expect(output_mode.minify).to be true
    end
  end

  describe "SearchField" do
    let(:search_field) { described_class::SearchField.new }

    it "has sensible defaults" do
      expect(search_field.boost).to eq(1)
      expect(search_field.searchable).to be true
    end

    it "can be configured" do
      search_field.name = "testField"
      search_field.boost = 5
      search_field.searchable = false

      expect(search_field.name).to eq("testField")
      expect(search_field.boost).to eq(5)
      expect(search_field.searchable).to be false
    end
  end

  describe "DocumentType" do
    let(:doc_type) { described_class::DocumentType.new }

    it "has sensible defaults" do
      expect(doc_type.boost).to eq(1.0)
      expect(doc_type.enabled).to be true
    end

    it "can be configured" do
      doc_type.type = "class"
      doc_type.boost = 1.5
      doc_type.enabled = false

      expect(doc_type.type).to eq("class")
      expect(doc_type.boost).to eq(1.5)
      expect(doc_type.enabled).to be false
    end
  end

  describe "integration" do
    it "loads and validates complete configuration" do
      config = described_class.load

      expect(config.version).to be_a(String)
      expect(config.output).to be_a(described_class::OutputConfig)
      expect(config.search).to be_a(described_class::SearchConfig)
      expect(config.ui).to be_a(described_class::UIConfig)
    end

    it "provides access to all configuration sections" do
      config = described_class.load

      expect(config.transformation_options).to be_a(Hash)
      expect(config.feature_flags).to be_a(Hash)
    end
  end
end
