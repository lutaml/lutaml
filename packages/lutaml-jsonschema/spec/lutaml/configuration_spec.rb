# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Lutaml::Jsonschema::Configuration do
  describe ".new" do
    it "has sensible defaults" do
      config = described_class.new
      expect(config.theme).to eq("light")
      expect(config.output_path).to eq("output")
      expect(config.title).to be_nil
    end
  end

  describe ".load_from_file" do
    it "loads configuration from YAML" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "config.yml")
        File.write(path, <<~YAML)
          title: Test Docs
          version: "1.0"
          theme: dark
          output_path: /tmp/docs
        YAML
        config = described_class.load_from_file(path)
        expect(config.title).to eq("Test Docs")
        expect(config.version).to eq("1.0")
        expect(config.theme).to eq("dark")
        expect(config.output_path).to eq("/tmp/docs")
      end
    end

    it "returns defaults for missing file" do
      config = described_class.load_from_file("/nonexistent.yml")
      expect(config).to be_a(described_class)
      expect(config.theme).to eq("light")
    end
  end

  describe "#to_metadata" do
    it "converts to Spa::Metadata" do
      config = described_class.new
      config.title = "Test"
      config.version = "2.0"
      metadata = config.to_metadata
      expect(metadata).to be_a(Lutaml::Jsonschema::Spa::Metadata)
      expect(metadata.title).to eq("Test")
      expect(metadata.version).to eq("2.0")
    end
  end

  describe "#apply_appearance_overrides" do
    it "sets logo for both light and dark themes" do
      config = described_class.new
      config.apply_appearance_overrides(logo: "https://example.com/logo.png",
                                        subtitle: nil)
      expect(config.appearance["logos"]["square"]["light"]["url"]).to eq("https://example.com/logo.png")
      expect(config.appearance["logos"]["square"]["dark"]["url"]).to eq("https://example.com/logo.png")
    end

    it "sets subtitle" do
      config = described_class.new
      config.apply_appearance_overrides(logo: nil, subtitle: "My API Docs")
      expect(config.appearance["subtitle"]).to eq("My API Docs")
    end

    it "sets both logo and subtitle" do
      config = described_class.new
      config.apply_appearance_overrides(logo: "logo.png", subtitle: "Sub")
      expect(config.appearance["logos"]["square"]["light"]["url"]).to eq("logo.png")
      expect(config.appearance["subtitle"]).to eq("Sub")
    end

    it "initializes appearance structure even without overrides" do
      config = described_class.new
      config.apply_appearance_overrides(logo: nil, subtitle: nil)
      expect(config.appearance).to be_a(Hash)
    end

    it "merges with existing appearance" do
      config = described_class.new
      config.appearance = { "existing" => "value" }
      config.apply_appearance_overrides(logo: "logo.png", subtitle: nil)
      expect(config.appearance["existing"]).to eq("value")
      expect(config.appearance["logos"]["square"]["light"]["url"]).to eq("logo.png")
    end
  end
end
