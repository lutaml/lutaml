# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/configuration"

RSpec.describe Lutaml::Ea::Diagram::Configuration do
  let(:config_path) { "spec/fixtures/diagram_styles.yml" }
  let(:config) { described_class.new(config_path) }

  # Helper to create a mock element with specified properties
  def mock_element(name: nil, stereotype: nil, package_name: nil) # rubocop:disable Metrics/AbcSize
    element = double("Element")
    allow(element).to receive(:name).and_return(name) if name
    allow(element).to receive(:stereotype).and_return(stereotype) if stereotype
    if package_name
      allow(element).to receive(:package_name).and_return(package_name)
    end
    allow(element).to receive(:respond_to?).with(:name).and_return(!name.nil?)
    allow(element)
      .to receive(:respond_to?).with(:stereotype).and_return(!stereotype.nil?)
    allow(element)
      .to receive(:respond_to?).with(:package_name)
      .and_return(!package_name.nil?)
    element
  end

  before do
    # Create a test configuration file
    FileUtils.mkdir_p("spec/fixtures")
    File.write("spec/fixtures/diagram_styles.yml", <<~YAML)
      defaults:
        colors:
          background: "#FFFFFF"
          default_fill: "#E0E0E0"
          default_stroke: "#000000"
        fonts:
          default:
            family: "Arial, sans-serif"
            size: 9
            weight: 400
          class_name:
            family: "Arial, sans-serif"
            size: 9
            weight: 700
        box:
          stroke_width: 2
          padding: 5

      stereotypes:
        DataType:
          colors:
            fill: "#FFCCFF"
            stroke: "#000000"
          fonts:
            class_name:
              weight: 700
              style: italic

        FeatureType:
          colors:
            fill: "#FFFFCC"

      packages:
        "CityGML::*":
          colors:
            fill: "#FFFFCC"

        "i-UR::*":
          colors:
            fill: "#FFCCFF"

      classes:
        SpecialClass:
          colors:
            fill: "#FF0000"

      connectors:
        generalization:
          arrow:
            type: hollow_triangle
            size: 10
          line:
            stroke_width: 1

      legend:
        enabled: true
        position: bottom_right
    YAML
  end

  after do
    FileUtils.rm_f("spec/fixtures/diagram_styles.yml")
  end

  describe "#initialize" do
    it "loads configuration from file", :aggregate_failures do
      expect(config.config_data).to be_a(Hash)
      expect(config.config_data["defaults"]).to be_a(Hash)
    end

    it "uses built-in defaults when no file exists", :aggregate_failures do
      config_no_file = described_class.new("nonexistent.yml")
      expect(config_no_file.config_data["defaults"]).to be_a(Hash)
      expect(config_no_file.config_data["defaults"]["colors"]["background"])
        .to eq("#FFFFFF")
    end

    it "merges configuration with defaults", :aggregate_failures do
      expect(config.config_data["defaults"]["colors"]["background"])
        .to eq("#FFFFFF")
      expect(config.config_data["stereotypes"]["DataType"]["colors"]["fill"])
        .to eq("#FFCCFF")
    end
  end

  describe "#style_for" do
    context "with class-specific override" do
      it "returns class-specific style (highest priority)" do
        element = mock_element(name: "SpecialClass", stereotype: ["DataType"])
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FF0000")
      end
    end

    context "with package-based styling" do
      it "returns package-specific style for exact match" do
        element = mock_element(name: "MyClass", package_name: "CityGML::Core")
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FFFFCC")
      end

      it "returns package-specific style for wildcard match" do
        element = mock_element(name: "MyClass", package_name: "i-UR::DataTypes")
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FFCCFF")
      end

      it "does not match unrelated packages" do
        element = mock_element(name: "MyClass", package_name: "Other::Package")
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#E0E0E0") # Falls back to default
      end
    end

    context "with stereotype-based styling" do
      it "returns stereotype-specific style" do
        element = mock_element(name: "MyClass", stereotype: ["DataType"])
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FFCCFF")
      end

      it "handles multiple stereotypes" do
        element = mock_element(name: "MyClass",
                               stereotype: [
                                 "DataType", "Abstract"
                               ])
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FFCCFF") # First matching stereotype
      end

      it "returns nested stereotype properties" do
        element = mock_element(name: "MyClass", stereotype: ["DataType"])
        font_weight = config.style_for(element, "fonts.class_name.weight")
        expect(font_weight).to eq(700)
      end
    end

    context "with default values" do
      it "returns default when no overrides exist" do
        element = mock_element(name: "PlainClass")
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#E0E0E0")
      end

      it "returns nested default values" do
        element = mock_element(name: "PlainClass")
        font_family = config.style_for(element, "fonts.default.family")
        expect(font_family).to eq("Arial, sans-serif")
      end
    end

    context "with priority resolution" do
      it "prioritizes class > package > stereotype > defaults" do
        # Class-specific wins over stereotype
        element = mock_element(
          name: "SpecialClass",
          stereotype: ["DataType"],
          package_name: "CityGML::Core",
        )
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FF0000") # Class-specific, not DataType pink
      end

      it "prioritizes package > stereotype when no class override" do
        element = mock_element(
          name: "RegularClass",
          stereotype: ["DataType"],
          package_name: "CityGML::Core",
        )
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FFFFCC") # Package yellow, not DataType pink
      end

      it "prioritizes stereotype > defaults when no package/class override" do
        element = mock_element(name: "RegularClass", stereotype: ["DataType"])
        fill_color = config.style_for(element, "colors.fill")
        expect(fill_color).to eq("#FFCCFF") # DataType pink, not default gray
      end
    end

    context "with edge cases" do
      it "returns nil for nil property" do
        element = mock_element(name: "MyClass")
        expect(config.style_for(element, nil)).to be_nil
      end

      it "returns nil for empty property" do
        element = mock_element(name: "MyClass")
        expect(config.style_for(element, "")).to be_nil
      end

      it "returns nil for non-existent property" do
        element = mock_element(name: "MyClass")
        expect(config.style_for(element, "nonexistent.property")).to be_nil
      end
    end
  end

  describe "#connector_style" do
    it "returns connector style for type" do
      arrow_type = config.connector_style("generalization", "arrow.type")
      expect(arrow_type).to eq("hollow_triangle")
    end

    it "returns nested connector properties" do
      stroke_width = config.connector_style("generalization",
                                            "line.stroke_width")
      expect(stroke_width).to eq(1)
    end

    it "returns nil for non-existent connector type" do
      result = config.connector_style("nonexistent", "arrow.type")
      expect(result).to be_nil
    end
  end

  describe "#legend_config" do
    it "returns legend configuration", :aggregate_failures do
      legend = config.legend_config
      expect(legend).to be_a(Hash)
      expect(legend["enabled"]).to be true
      expect(legend["position"]).to eq("bottom_right")
    end

    it "returns empty hash when legend not configured" do
      config_no_legend = described_class.new
      legend = config_no_legend.legend_config
      expect(legend).to be_a(Hash)
    end
  end

  describe "#to_h" do
    it "returns complete configuration data", :aggregate_failures do
      data = config.to_h
      expect(data).to be_a(Hash)
      expect(data).to have_key("defaults")
      expect(data).to have_key("stereotypes")
    end
  end

  describe "private methods" do
    describe "#matches_package?" do
      it "matches exact package names" do
        result = config.send(:matches_package?, "CityGML::Core", "CityGML::Core")
        expect(result).to be true
      end

      it "matches wildcard patterns" do
        result = config.send(:matches_package?, "CityGML::Core", "CityGML::*")
        expect(result).to be true
      end

      it "does not match unrelated packages" do
        result = config.send(:matches_package?, "Other::Package", "CityGML::*")
        expect(result).to be false
      end

      it "handles nil package names" do
        result = config.send(:matches_package?, nil, "CityGML::*")
        expect(result).to be false
      end

      it "handles nil patterns" do
        result = config.send(:matches_package?, "CityGML::Core", nil)
        expect(result).to be false
      end

      it "handles complex wildcard patterns" do
        result = config.send(:matches_package?, "CityGML::Core::Feature",
                             "CityGML::*")
        expect(result).to be true
      end
    end

    describe "#dig_hash" do
      it "navigates nested hashes with dot notation" do
        hash = { "a" => { "b" => { "c" => "value" } } }
        result = config.send(:dig_hash, hash, "a.b.c")
        expect(result).to eq("value")
      end

      it "returns nil for non-existent paths" do
        hash = { "a" => { "b" => "value" } }
        result = config.send(:dig_hash, hash, "a.x.y")
        expect(result).to be_nil
      end

      it "returns nil for nil path" do
        hash = { "a" => "value" }
        result = config.send(:dig_hash, hash, nil)
        expect(result).to be_nil
      end

      it "returns nil for empty path" do
        hash = { "a" => "value" }
        result = config.send(:dig_hash, hash, "")
        expect(result).to be_nil
      end
    end

    describe "#deep_merge" do
      it "merges nested hashes", :aggregate_failures do
        hash1 = { "a" => { "b" => 1, "c" => 2 } }
        hash2 = { "a" => { "b" => 3, "d" => 4 } }
        result = config.send(:deep_merge, hash1, hash2)

        expect(result["a"]["b"]).to eq(3) # Overridden
        expect(result["a"]["c"]).to eq(2) # Preserved from hash1
        expect(result["a"]["d"]).to eq(4) # Added from hash2
      end

      it "handles non-hash values" do
        hash1 = { "a" => 1 }
        hash2 = { "a" => 2 }
        result = config.send(:deep_merge, hash1, hash2)

        expect(result["a"]).to eq(2)
      end

      it "preserves keys from both hashes" do
        hash1 = { "a" => 1, "b" => 2 }
        hash2 = { "c" => 3 }
        result = config.send(:deep_merge, hash1, hash2)

        expect(result).to eq({ "a" => 1, "b" => 2, "c" => 3 })
      end
    end
  end

  describe "configuration file loading" do
    it "handles YAML parse errors gracefully" do
      FileUtils.mkdir_p("spec/fixtures")
      File.write("spec/fixtures/invalid.yml", "invalid: yaml: content:")

      expect do
        described_class.new("spec/fixtures/invalid.yml")
      end.not_to raise_error

      FileUtils.rm_f("spec/fixtures/invalid.yml")
    end

    it "prioritizes user config over defaults" do
      expect(config.config_data["defaults"]["colors"]["background"])
        .to eq("#FFFFFF")
    end
  end

  describe "built-in stereotypes" do
    let(:config_defaults) { described_class.new }

    it "has DataType stereotype configured" do
      element = mock_element(name: "MyType", stereotype: ["DataType"])
      fill_color = config_defaults.style_for(element, "colors.fill")
      expect(fill_color).to eq("#FFCCFF")
    end

    it "has FeatureType stereotype configured" do
      element = mock_element(name: "MyFeature", stereotype: ["FeatureType"])
      fill_color = config_defaults.style_for(element, "colors.fill")
      expect(fill_color).to eq("#FFFFCC")
    end

    it "has GMLType stereotype configured" do
      element = mock_element(name: "MyGML", stereotype: ["GMLType"])
      fill_color = config_defaults.style_for(element, "colors.fill")
      expect(fill_color).to eq("#CCFFCC")
    end

    it "has Interface stereotype configured" do
      element = mock_element(name: "MyInterface", stereotype: ["Interface"])
      fill_color = config_defaults.style_for(element, "colors.fill")
      expect(fill_color).to eq("#FFFFEE")
    end
  end
end
