# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/configuration_loader"

RSpec.describe Lutaml::Xsd::Spa::ConfigurationLoader do
  let(:temp_config_dir) do
    dir = File.join(Dir.pwd, "tmp_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(dir)
    dir
  end
  let(:valid_theme_yaml) do
    <<~YAML
      theme:
        colors:
          primary: "#2563eb"
          secondary: "#64748b"
        typography:
          font_family: "Arial"
        layout:
          sidebar_width: "280px"
        dark_colors:
          primary: "#60a5fa"
    YAML
  end
  let(:valid_features_yaml) do
    <<~YAML
      features:
        search:
          enabled: true
        filtering:
          enabled: false
          max_results: 100
    YAML
  end
  let(:invalid_yaml) { "invalid: yaml: content: [" }

  subject(:loader) { described_class.new(config_dir: temp_config_dir) }

  after do
    FileUtils.rm_rf(temp_config_dir)
  end

  describe "#initialize" do
    it "uses default config directory when not specified" do
      default_loader = described_class.new
      expect(default_loader.config_dir).to eq(described_class::DEFAULT_CONFIG_DIR)
    end

    it "accepts custom config directory" do
      expect(loader.config_dir).to eq(temp_config_dir)
    end
  end

  describe "#theme" do
    context "when theme file exists" do
      before do
        File.write(File.join(temp_config_dir, "ui_theme.yml"), valid_theme_yaml)
      end

      it "loads theme configuration from file" do
        theme = loader.theme
        expect(theme["theme"]["colors"]["primary"]).to eq("#2563eb")
      end

      it "caches loaded configuration" do
        loader.theme
        expect(File).not_to receive(:read)
        loader.theme
      end
    end

    context "when theme file does not exist" do
      it "returns default theme configuration" do
        theme = loader.theme
        expect(theme["theme"]["colors"]["primary"]).to eq("#2563eb")
      end
    end

    context "when theme file contains invalid YAML" do
      before do
        File.write(File.join(temp_config_dir, "ui_theme.yml"), invalid_yaml)
      end

      it "returns default theme configuration" do
        expect do
          loader.theme
        end.to output(/Failed to parse ui_theme\.yml/).to_stderr
        theme = loader.theme
        expect(theme).to eq(loader.send(:default_theme))
      end
    end
  end

  describe "#features" do
    context "when features file exists" do
      before do
        File.write(File.join(temp_config_dir, "features.yml"),
                   valid_features_yaml)
      end

      it "loads features configuration from file" do
        features = loader.features
        expect(features["features"]["search"]["enabled"]).to be true
      end
    end

    context "when features file does not exist" do
      it "returns default features configuration" do
        features = loader.features
        expect(features["features"]["search"]["enabled"]).to be true
      end
    end
  end

  describe "#templates" do
    context "when templates file does not exist" do
      it "returns default templates configuration" do
        templates = loader.templates
        expect(templates["templates"]["layout"]).to eq("default")
      end
    end
  end

  describe "#color" do
    before do
      File.write(File.join(temp_config_dir, "ui_theme.yml"), valid_theme_yaml)
    end

    context "when light mode" do
      it "returns light color value" do
        color = loader.color("primary", dark_mode: false)
        expect(color).to eq("#2563eb")
      end
    end

    context "when dark mode" do
      it "returns dark color value" do
        color = loader.color("primary", dark_mode: true)
        expect(color).to eq("#60a5fa")
      end
    end

    context "when color key does not exist" do
      it "returns default black color" do
        color = loader.color("nonexistent")
        expect(color).to eq("#000000")
      end
    end

    context "when dark color does not exist" do
      it "returns default black color" do
        color = loader.color("nonexistent", dark_mode: true)
        expect(color).to eq("#000000")
      end
    end
  end

  describe "#typography" do
    before do
      File.write(File.join(temp_config_dir, "ui_theme.yml"), valid_theme_yaml)
    end

    it "returns typography value" do
      font = loader.typography("font_family")
      expect(font).to eq("Arial")
    end

    it "returns nil for missing typography key" do
      result = loader.typography("nonexistent")
      expect(result).to be_nil
    end
  end

  describe "#layout" do
    before do
      File.write(File.join(temp_config_dir, "ui_theme.yml"), valid_theme_yaml)
    end

    it "returns layout value" do
      width = loader.layout("sidebar_width")
      expect(width).to eq("280px")
    end

    it "returns nil for missing layout key" do
      result = loader.layout("nonexistent")
      expect(result).to be_nil
    end
  end

  describe "#feature_enabled?" do
    before do
      File.write(File.join(temp_config_dir, "features.yml"),
                 valid_features_yaml)
    end

    it "returns true for enabled feature" do
      expect(loader.feature_enabled?("search")).to be true
    end

    it "returns false for disabled feature" do
      expect(loader.feature_enabled?("filtering")).to be false
    end

    it "returns false for nonexistent feature" do
      expect(loader.feature_enabled?("nonexistent")).to be false
    end
  end

  describe "#feature_setting" do
    before do
      File.write(File.join(temp_config_dir, "features.yml"),
                 valid_features_yaml)
    end

    it "returns feature setting value" do
      max_results = loader.feature_setting("filtering", "max_results")
      expect(max_results).to eq(100)
    end

    it "returns default value for missing setting" do
      result = loader.feature_setting("search", "nonexistent", default: 42)
      expect(result).to eq(42)
    end

    it "returns nil when default not specified" do
      result = loader.feature_setting("search", "nonexistent")
      expect(result).to be_nil
    end
  end

  describe "#template_components" do
    it "returns components for default layout" do
      components = loader.template_components
      expect(components).to be_an(Array)
      expect(components).not_to be_empty
    end

    it "returns empty array for nonexistent layout" do
      components = loader.template_components(layout_name: "nonexistent")
      expect(components).to eq([])
    end
  end

  describe "#partial_template" do
    it "returns nil for default configuration" do
      result = loader.partial_template("schema_card")
      expect(result).to be_nil
    end
  end

  describe "#reload!" do
    before do
      File.write(File.join(temp_config_dir, "ui_theme.yml"), valid_theme_yaml)
    end

    it "clears configuration cache" do
      # Load configuration
      loader.theme

      # Modify file
      new_yaml = valid_theme_yaml.gsub("#2563eb", "#000000")
      File.write(File.join(temp_config_dir, "ui_theme.yml"), new_yaml)

      # Reload
      loader.reload!

      # Verify new value is loaded
      theme = loader.theme
      expect(theme["theme"]["colors"]["primary"]).to eq("#000000")
    end
  end

  describe "caching behavior" do
    before do
      File.write(File.join(temp_config_dir, "ui_theme.yml"), valid_theme_yaml)
    end

    it "caches multiple configuration types independently" do
      theme = loader.theme
      features = loader.features

      expect(theme).not_to eq(features)
      expect(theme["theme"]).to be_a(Hash)
      expect(features["features"]).to be_a(Hash)
    end
  end
end
