# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/extractor"
require "lutaml/uml_repository/repository"
require "tmpdir"

RSpec.describe Lutaml::Ea::Diagram::Extractor do
  let(:extractor) { described_class.new }
  let(:lur_path) { "spec/fixtures/test.lur" }
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.remove_entry(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  describe "#initialize" do
    it "creates extractor with default options" do
      expect(extractor.options).to include(
        format: "svg",
        padding: 20,
        background_color: "#ffffff",
        grid_visible: false,
        interactive: false,
      )
    end

    it "accepts custom options" do
      custom_extractor = described_class.new(
        padding: 30,
        background_color: "#f0f0f0",
        interactive: true,
      )

      expect(custom_extractor.options).to include(
        padding: 30,
        background_color: "#f0f0f0",
        interactive: true,
      )
    end

    context "with environment variables" do
      around do |example|
        original_env = ENV.to_hash
        ENV["LUTAML_DIAGRAM_PADDING"] = "50"
        ENV["LUTAML_DIAGRAM_BG_COLOR"] = "#eeeeee"
        ENV["LUTAML_DIAGRAM_GRID"] = "true"
        ENV["LUTAML_DIAGRAM_INTERACTIVE"] = "true"
        ENV["LUTAML_DIAGRAM_CONFIG"] = "/path/to/config.yml"

        example.run

        ENV.replace(original_env)
      end

      it "loads options from environment variables" do
        env_extractor = described_class.new

        expect(env_extractor.options).to include(
          padding: 50,
          background_color: "#eeeeee",
          grid_visible: true,
          interactive: true,
          config_path: "/path/to/config.yml",
        )
      end

      it "allows user options to override environment variables" do
        override_extractor = described_class.new(padding: 100)

        expect(override_extractor.options[:padding]).to eq(100)
      end
    end
  end

  describe "#extract_one" do
    context "with non-existent file" do
      it "returns failure result" do
        result = extractor.extract_one("nonexistent.lur", "diagram1")

        expect(result[:success]).to be false
        expect(result[:message]).to include("File not found")
      end
    end

    context "with valid LUR file", :requires_fixtures do
      let(:diagram_name) { "TestSchema" }
      let(:output_path) { File.join(temp_dir, "output.svg") }

      it "extracts diagram successfully" do
        result = extractor.extract_one(lur_path, diagram_name,
                                       output: output_path)

        expect(result[:success]).to be true
        expect(result[:path]).to eq(output_path)
        expect(result[:format]).to eq("svg")
        expect(result[:diagram]).to include(:name, :type, :objects, :links)
        expect(File.exist?(output_path)).to be true
      end

      it "outputs SVG content if output path not specified" do
        result = extractor.extract_one(lur_path, diagram_name)

        expect(result[:success]).to be true
        expect(!!result[:svg_content]).to be true
      end
    end

    context "with non-existent diagram" do
      it "returns failure with available diagrams", :requires_fixtures do
        result = extractor.extract_one(lur_path, "nonexistent_diagram")

        expect(result[:success]).to be false
        expect(result[:message]).to include("Diagram not found")
        expect(result[:available]).to be_an(Array)
      end
    end
  end

  describe "#list_diagrams" do
    context "with non-existent file" do
      it "returns failure result" do
        result = extractor.list_diagrams("nonexistent.lur")

        expect(result[:success]).to be false
        expect(result[:message]).to include("File not found")
      end
    end

    context "with valid LUR file", :requires_fixtures do
      it "lists all diagrams" do
        result = extractor.list_diagrams(lur_path)

        expect(result[:success]).to be true
        expect(result[:count]).to be >= 0
        expect(result[:diagrams]).to be_an(Array)
      end

      it "includes diagram details" do
        result = extractor.list_diagrams(lur_path)

        if result[:diagrams].any?
          diagram = result[:diagrams].first
          expect(diagram).to include(
            :xmi_id,
            :name,
            :type,
            :package,
            :objects,
            :links,
          )
        end
      end
    end
  end

  describe "#extract_batch" do
    let(:diagram_ids) { ["diagram1", "diagram2", "diagram3"] }
    let(:output_dir) { File.join(temp_dir, "diagrams") }

    context "with non-existent file" do
      it "returns failure result" do
        result = extractor.extract_batch("nonexistent.lur", diagram_ids)

        expect(result[:success]).to be false
      end
    end

    context "with valid LUR file", :requires_fixtures do
      it "creates output directory if it doesn't exist" do
        expect(Dir.exist?(output_dir)).to be false

        extractor.extract_batch(lur_path, diagram_ids, output_dir: output_dir)

        expect(Dir.exist?(output_dir)).to be true
      end

      it "extracts multiple diagrams" do
        result = extractor.extract_batch(lur_path, diagram_ids,
                                         output_dir: output_dir)

        expect(result[:results]).to be_an(Array)
        expect(result[:results].size).to eq(diagram_ids.size)
        expect(result[:summary]).to include(:total, :successful, :failed)
      end

      it "returns success when all diagrams extracted" do
        # This test depends on fixture data
        result = extractor.extract_batch(lur_path, [], output_dir: output_dir)

        expect(result[:summary][:total]).to eq(0)
      end
    end
  end

  describe "private methods" do
    describe "#sanitize_filename" do
      it "replaces invalid characters with underscores" do
        result = extractor.send(:sanitize_filename, "My Diagram/Name: Test")

        expect(result).to eq("My_Diagram_Name__Test")
      end

      it "preserves valid characters" do
        result = extractor.send(:sanitize_filename, "valid_diagram-123")

        expect(result).to eq("valid_diagram-123")
      end
    end

    describe "#format_cardinality" do
      it "formats cardinality with to_s" do
        cardinality = double(to_s: "1..*")
        result = extractor.send(:format_cardinality, cardinality)

        expect(result).to eq("1..*")
      end

      it "returns empty string for nil" do
        result = extractor.send(:format_cardinality, nil)

        expect(result).to eq("")
      end
    end

    describe "#element_type" do
      it "returns correct type for Class" do
        klass = Lutaml::Uml::Class.new(name: "TestClass")
        result = extractor.send(:element_type, klass)

        expect(result).to eq("class")
      end

      it "returns correct type for Package" do
        package = Lutaml::Uml::Package.new(name: "TestPackage")
        result = extractor.send(:element_type, package)

        expect(result).to eq("package")
      end

      it "returns correct type for DataType" do
        datatype = Lutaml::Uml::DataType.new(name: "TestDataType")
        result = extractor.send(:element_type, datatype)

        expect(result).to eq("datatype")
      end

      it "returns correct type for Enum" do
        enum = Lutaml::Uml::Enum.new(name: "TestEnum")
        result = extractor.send(:element_type, enum)

        expect(result).to eq("enumeration")
      end

      it "returns unknown for other types" do
        other = Object.new
        result = extractor.send(:element_type, other)

        expect(result).to eq("unknown")
      end
    end

    describe "#connector_type" do
      it "returns correct type for Association" do
        assoc = Lutaml::Uml::Association.new
        result = extractor.send(:connector_type, assoc)

        expect(result).to eq("association")
      end

      it "returns connector for unknown types" do
        other = Object.new
        result = extractor.send(:connector_type, other)

        expect(result).to eq("connector")
      end
    end

    describe "#default_output_path" do
      it "generates path from diagram name" do
        diagram = double(name: "Test Diagram")
        result = extractor.send(:default_output_path, diagram)

        expect(result).to eq("Test_Diagram.svg")
      end
    end
  end
end