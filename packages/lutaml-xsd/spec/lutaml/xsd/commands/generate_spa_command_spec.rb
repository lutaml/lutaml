# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/generate_spa_command"

RSpec.describe Lutaml::Xsd::Commands::GenerateSpaCommand do
  let(:package_path) { "/tmp/test.lxr" }
  let(:output_path) { "/tmp/docs.html" }

  let(:mock_package) do
    instance_double(
      Lutaml::Xsd::SchemaRepositoryPackage,
      schemas: [],
    )
  end

  let(:mock_generator) do
    instance_double(
      Lutaml::Xsd::Spa::Generator,
      generate: ["/tmp/docs.html"],
    )
  end

  describe "#initialize" do
    it "accepts package_path and options" do
      command = described_class.new(package_path, output: output_path)

      expect(command.package_path).to eq(package_path)
      expect(command.output_path).to eq(output_path)
    end

    it "extracts output option" do
      command = described_class.new(package_path, output: output_path)
      expect(command.output_path).to eq(output_path)
    end
  end

  describe "#run" do
    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load).and_return(mock_package)
      allow(Lutaml::Xsd::Spa::Generator).to receive(:new).and_return(mock_generator)
    end

    context "with inlined mode" do
      let(:command) do
        described_class.new(
          package_path,
          output: output_path,
          mode: "inlined",
        )
      end

      it "validates inputs" do
        expect(command).to receive(:validate_inputs)
        command.run
      end

      it "loads package" do
        expect(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load).with(package_path)
        command.run
      end

      it "creates generator with inlined mode" do
        expect(Lutaml::Xsd::Spa::Generator).to receive(:new).with(
          mock_package,
          output_path,
          hash_including(mode: "inlined"),
        )
        command.run
      end

      it "generates output" do
        expect(mock_generator).to receive(:generate)
        command.run
      end

      it "displays results" do
        expect(command).to receive(:display_results)
        command.run
      end
    end

    context "with cdn mode" do
      let(:command) do
        described_class.new(
          package_path,
          output: output_path,
          mode: "cdn",
        )
      end

      it "creates generator with cdn mode" do
        expect(Lutaml::Xsd::Spa::Generator).to receive(:new).with(
          mock_package,
          output_path,
          hash_including(mode: "cdn"),
        )
        command.run
      end
    end

    context "when error occurs" do
      let(:command) { described_class.new(package_path, output: output_path) }

      it "catches and handles error" do
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load).and_raise(
          StandardError, "Test error"
        )

        expect do
          command.run
        end.to raise_error(SystemExit)
      end

      it "outputs error message" do
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load).and_raise(
          StandardError, "Test error"
        )

        expect do
          command.run
        rescue SystemExit
          # Expected
        end.to output(/SPA generation failed/).to_stderr
      end
    end
  end

  describe "#validate_inputs" do
    context "when package_path is nil" do
      let(:command) { described_class.new(nil) }

      it "exits with error" do
        expect do
          command.send(:validate_inputs)
        end.to raise_error(SystemExit)
      end

      it "outputs error message" do
        expect do
          command.send(:validate_inputs)
        rescue SystemExit
          # Expected
        end.to output(/No package file specified/).to_stderr
      end
    end

    context "when package file does not exist" do
      let(:command) { described_class.new(package_path, output: output_path) }

      before do
        allow(File).to receive(:exist?).with(package_path).and_return(false)
      end

      it "exits with error" do
        expect do
          command.send(:validate_inputs)
        end.to raise_error(SystemExit)
      end

      it "outputs error message" do
        expect do
          command.send(:validate_inputs)
        rescue SystemExit
          # Expected
        end.to output(/Package file not found/).to_stderr
      end
    end

    context "when no output option" do
      let(:command) { described_class.new(package_path) }

      before do
        allow(File).to receive(:exist?).and_return(true)
      end

      it "exits with error" do
        expect do
          command.send(:validate_inputs)
        end.to raise_error(SystemExit)
      end

      it "outputs error message" do
        expect do
          command.send(:validate_inputs)
        rescue SystemExit
          # Expected
        end.to output(/No output file specified/).to_stderr
      end
    end
  end

  describe "#load_package" do
    let(:command) { described_class.new(package_path, output: output_path) }

    before do
      allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load).and_return(mock_package)
    end

    it "loads package from file" do
      expect(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:load).with(package_path)
      command.send(:load_package)
    end

    it "returns package" do
      result = command.send(:load_package)
      expect(result).to eq(mock_package)
    end

    context "when verbose mode enabled" do
      let(:command) do
        described_class.new(package_path, output: output_path, verbose: true)
      end

      it "outputs loading message" do
        expect do
          command.send(:load_package)
        end.to output(/Loading package/).to_stdout
      end

      it "outputs success message" do
        expect do
          command.send(:load_package)
        end.to output(/Package loaded/).to_stdout
      end
    end
  end

  describe "#create_generator" do
    let(:command) do
      described_class.new(package_path, output: output_path,
                                        mode: "inlined")
    end

    before do
      allow(Lutaml::Xsd::Spa::Generator).to receive(:new).and_return(mock_generator)
    end

    it "creates generator with correct parameters" do
      expect(Lutaml::Xsd::Spa::Generator).to receive(:new).with(
        mock_package,
        output_path,
        hash_including(mode: "inlined"),
      )
      command.send(:create_generator, mock_package)
    end

    it "returns generator" do
      result = command.send(:create_generator, mock_package)
      expect(result).to eq(mock_generator)
    end

    context "when verbose mode enabled" do
      let(:command) do
        described_class.new(package_path, output: output_path, verbose: true)
      end

      it "outputs initialization message" do
        expect do
          command.send(:create_generator, mock_package)
        end.to output(/Initializing SPA generator/).to_stdout
      end

      it "outputs success message" do
        expect do
          command.send(:create_generator, mock_package)
        end.to output(/Generator initialized/).to_stdout
      end
    end
  end

  describe "#display_results" do
    let(:command) { described_class.new(package_path, output: output_path) }

    context "with single file" do
      let(:files) { ["/tmp/docs.html"] }

      it "displays single file message" do
        expect do
          command.send(:display_results, files)
        end.to output(/Output file/).to_stdout
      end

      it "displays file path" do
        expect do
          command.send(:display_results, files)
        end.to output(%r{/tmp/docs\.html}).to_stdout
      end
    end

    context "with multiple files" do
      let(:files) { ["/tmp/index.html", "/tmp/styles.css", "/tmp/app.js"] }

      it "displays multiple files message" do
        expect do
          command.send(:display_results, files)
        end.to output(/Output files.*3 total/).to_stdout
      end

      it "lists all files" do
        output = capture_stdout do
          command.send(:display_results, files)
        end

        files.each do |file|
          expect(output).to include(file)
        end
      end
    end

    it "displays success message" do
      expect do
        command.send(:display_results, [output_path])
      end.to output(/Generation complete/).to_stdout
    end
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
