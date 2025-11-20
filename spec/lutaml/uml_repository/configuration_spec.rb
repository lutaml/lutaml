# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/configuration"
require "tempfile"
require "tmpdir"

RSpec.describe Lutaml::UmlRepository::Configuration do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    it "creates a configuration with default values" do
      config = described_class.new

      expect(config.default_format).to eq(:marshal)
      expect(config.default_base_path).to eq(Dir.pwd)
      expect(config.recent_packages).to eq([])
      expect(config.package_aliases).to eq({})
      expect(config.ui_preferences).to be_a(Hash)
      expect(config.ui_preferences["colorize"]).to eq(true)
    end

    it "accepts custom attributes" do
      config = described_class.new(
        default_format: :yaml,
        default_base_path: "/custom/path",
        recent_packages: ["/path/to/model.lur"],
        package_aliases: { "my-model" => "/path/to/model.lur" },
        ui_preferences: { "colorize" => false },
      )

      expect(config.default_format).to eq(:yaml)
      expect(config.default_base_path).to eq("/custom/path")
      expect(config.recent_packages).to eq(["/path/to/model.lur"])
      expect(config.package_aliases).to eq({ "my-model" => "/path/to/model.lur" })
      expect(config.ui_preferences["colorize"]).to eq(false)
    end
  end

  describe ".load" do
    context "when config file exists" do
      it "loads configuration from file" do
        config_data = {
          "default_format" => "yaml",
          "default_base_path" => "/test/path",
          "recent_packages" => ["/model1.lur", "/model2.lur"],
          "package_aliases" => { "test" => "/test.lur" },
          "ui_preferences" => { "colorize" => false },
        }

        config_path = File.join(temp_dir, ".lutaml-xmi.yaml")
        File.write(config_path, YAML.dump(config_data))

        config = described_class.load(temp_dir)

        expect(config.default_format).to eq(:yaml)
        expect(config.default_base_path).to eq("/test/path")
        expect(config.recent_packages).to eq(["/model1.lur", "/model2.lur"])
        expect(config.package_aliases).to eq({ "test" => "/test.lur" })
        expect(config.ui_preferences["colorize"]).to eq(false)
      end
    end

    context "when config file does not exist" do
      it "returns configuration with default values" do
        config = described_class.load(temp_dir)

        expect(config.default_format).to eq(:marshal)
        expect(config.default_base_path).to eq(Dir.pwd)
        expect(config.recent_packages).to eq([])
        expect(config.package_aliases).to eq({})
      end
    end
  end

  describe "#save" do
    it "saves configuration to file" do
      config = described_class.new(
        default_format: :yaml,
        default_base_path: "/custom/path",
        recent_packages: ["/model.lur"],
        package_aliases: { "my-model" => "/model.lur" },
        ui_preferences: { "colorize" => false },
      )

      config.save(temp_dir)

      config_path = File.join(temp_dir, ".lutaml-xmi.yaml")
      expect(File.exist?(config_path)).to be true

      loaded_data = YAML.load_file(config_path)
      expect(loaded_data["default_format"]).to eq("yaml")
      expect(loaded_data["default_base_path"]).to eq("/custom/path")
      expect(loaded_data["recent_packages"]).to eq(["/model.lur"])
      expect(loaded_data["package_aliases"]).to eq({ "my-model" => "/model.lur" })
      expect(loaded_data["ui_preferences"]["colorize"]).to eq(false)
    end
  end

  describe "#resolve_alias" do
    let(:config) do
      described_class.new(
        package_aliases: {
          "my-model" => "/path/to/model.lur",
          "test-model" => "/path/to/test.lur",
        },
      )
    end

    it "resolves alias starting with @" do
      expect(config.resolve_alias("@my-model")).to eq("/path/to/model.lur")
      expect(config.resolve_alias("@test-model")).to eq("/path/to/test.lur")
    end

    it "returns nil for unknown alias" do
      expect(config.resolve_alias("@unknown")).to be_nil
    end

    it "returns path unchanged if not an alias" do
      expect(config.resolve_alias("/direct/path.lur")).to eq("/direct/path.lur")
      expect(config.resolve_alias("relative/path.lur")).to eq("relative/path.lur")
    end
  end

  describe "#add_alias" do
    let(:config) { described_class.new }

    it "adds a new alias" do
      config.add_alias("my-model", "/path/to/model.lur")

      expect(config.package_aliases["my-model"]).to eq("/path/to/model.lur")
    end

    it "updates existing alias" do
      config.add_alias("my-model", "/path/to/model.lur")
      config.add_alias("my-model", "/new/path/to/model.lur")

      expect(config.package_aliases["my-model"]).to eq("/new/path/to/model.lur")
    end
  end

  describe "#remove_alias" do
    let(:config) do
      described_class.new(
        package_aliases: { "my-model" => "/path/to/model.lur" },
      )
    end

    it "removes an existing alias" do
      config.remove_alias("my-model")

      expect(config.package_aliases).not_to have_key("my-model")
    end

    it "does nothing for non-existent alias" do
      expect { config.remove_alias("unknown") }.not_to raise_error
    end
  end

  describe "#add_recent" do
    let(:config) { described_class.new }

    it "adds package to front of recent list" do
      config.add_recent("/model1.lur")
      config.add_recent("/model2.lur")

      expect(config.recent_packages).to eq(["/model2.lur", "/model1.lur"])
    end

    it "removes duplicates and moves to front" do
      config.add_recent("/model1.lur")
      config.add_recent("/model2.lur")
      config.add_recent("/model1.lur")

      expect(config.recent_packages).to eq(["/model1.lur", "/model2.lur"])
    end

    it "limits to 10 most recent packages" do
      11.times { |i| config.add_recent("/model#{i}.lur") }

      expect(config.recent_packages.size).to eq(10)
      expect(config.recent_packages.first).to eq("/model10.lur")
    end
  end

  describe "#clear_recent" do
    let(:config) do
      described_class.new(
        recent_packages: ["/model1.lur", "/model2.lur"],
      )
    end

    it "clears all recent packages" do
      config.clear_recent

      expect(config.recent_packages).to eq([])
    end
  end

  describe "#set_ui_preference" do
    let(:config) { described_class.new }

    it "sets a UI preference with string key" do
      config.set_ui_preference("custom_key", "custom_value")

      expect(config.ui_preferences["custom_key"]).to eq("custom_value")
    end

    it "sets a UI preference with symbol key" do
      config.set_ui_preference(:custom_key, "custom_value")

      expect(config.ui_preferences["custom_key"]).to eq("custom_value")
    end

    it "updates existing preference" do
      config.set_ui_preference(:colorize, false)

      expect(config.ui_preferences["colorize"]).to eq(false)
    end
  end

  describe "#get_ui_preference" do
    let(:config) do
      described_class.new(
        ui_preferences: { "colorize" => false, "custom" => "value" },
      )
    end

    it "gets existing preference with string key" do
      expect(config.get_ui_preference("colorize")).to eq(false)
      expect(config.get_ui_preference("custom")).to eq("value")
    end

    it "gets existing preference with symbol key" do
      expect(config.get_ui_preference(:colorize)).to eq(false)
      expect(config.get_ui_preference(:custom)).to eq("value")
    end

    it "returns default for non-existent preference" do
      expect(config.get_ui_preference("unknown", "default")).to eq("default")
    end

    it "returns nil for non-existent preference without default" do
      expect(config.get_ui_preference("unknown")).to be_nil
    end
  end

  describe "round-trip save and load" do
    it "preserves all configuration data" do
      original = described_class.new(
        default_format: :yaml,
        default_base_path: "/test/path",
        recent_packages: ["/model1.lur", "/model2.lur"],
        package_aliases: { "test" => "/test.lur" },
        ui_preferences: { "colorize" => false, "verbose" => true },
      )

      original.save(temp_dir)
      loaded = described_class.load(temp_dir)

      expect(loaded.default_format).to eq(original.default_format)
      expect(loaded.default_base_path).to eq(original.default_base_path)
      expect(loaded.recent_packages).to eq(original.recent_packages)
      expect(loaded.package_aliases).to eq(original.package_aliases)
      expect(loaded.ui_preferences).to eq(original.ui_preferences)
    end
  end
end
