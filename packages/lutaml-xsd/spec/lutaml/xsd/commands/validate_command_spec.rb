# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/validate_command"

RSpec.describe Lutaml::Xsd::Commands::ValidateCommand do
  let(:schema_path) { "spec/fixtures/schema.lxr" }
  let(:xml_file) { "spec/fixtures/valid.xml" }
  let(:options) { { verbose: false } }

  describe "#initialize" do
    it "accepts single file" do
      command = described_class.new(xml_file, schema_path, options)

      expect(command.xml_files).to eq([xml_file])
      expect(command.schema_source).to eq(schema_path)
    end

    it "accepts multiple files" do
      files = ["file1.xml", "file2.xml"]
      command = described_class.new(files, schema_path, options)

      expect(command.xml_files).to eq(files)
    end
  end

  describe "#run" do
    let(:command) { described_class.new([xml_file], schema_path, options) }

    before do
      allow(File).to receive(:exist?).with(xml_file).and_return(true)
      allow(File).to receive(:exist?).with(schema_path).and_return(true)
      allow(Dir).to receive(:glob).and_return([])
    end

    it "validates inputs before processing" do
      allow(File).to receive(:exist?).with(schema_path).and_return(false)

      expect { command.run }.to raise_error(SystemExit)
    end

    it "expands glob patterns" do
      pattern_command = described_class.new(["*.xml"], schema_path, options)
      allow(File).to receive(:exist?).with(schema_path).and_return(true)
      allow(Dir).to receive(:glob).with("*.xml").and_return([xml_file])
      allow(File).to receive(:read).and_return("<root/>")

      validator = double("validator")
      allow(Lutaml::Xsd::Validation::Validator).to receive(:new).and_return(validator)
      allow(validator).to receive(:validate).and_return(double(valid?: true,
                                                               errors: []))

      expect { pattern_command.run }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end
  end

  describe "output formats" do
    let(:command) { described_class.new([xml_file], schema_path, options) }
    let(:results) do
      [
        {
          file: xml_file,
          result: double(valid?: true, errors: []),
        },
      ]
    end

    before do
      allow(command).to receive(:exit_with_status)
    end

    it "outputs text format by default" do
      expect do
        command.send(:output_results,
                     results)
      end.to output(/Validation Results/).to_stdout
    end

    it "outputs JSON format when requested" do
      json_options = options.merge(format: "json")
      json_command = described_class.new([xml_file], schema_path, json_options)
      allow(json_command).to receive(:exit_with_status)

      expect do
        json_command.send(:output_results, results)
      end.to output(/"summary"/).to_stdout
    end

    it "outputs YAML format when requested" do
      yaml_options = options.merge(format: "yaml")
      yaml_command = described_class.new([xml_file], schema_path, yaml_options)
      allow(yaml_command).to receive(:exit_with_status)

      expect do
        yaml_command.send(:output_results, results)
      end.to output(/summary:/).to_stdout
    end
  end

  describe "exit codes" do
    let(:command) { described_class.new([xml_file], schema_path, options) }

    it "exits with 0 for valid files" do
      results = [
        { file: xml_file, result: double(valid?: true, errors: []) },
      ]

      expect do
        command.send(:exit_with_status,
                     results)
      end.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end

    it "exits with 1 for invalid files" do
      results = [
        { file: xml_file, result: double(valid?: false, errors: ["error"]) },
      ]

      expect do
        command.send(:exit_with_status,
                     results)
      end.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end
  end
end
