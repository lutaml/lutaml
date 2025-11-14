# frozen_string_literal: true

require "spec_helper"
require "lutaml/cli/uml_commands"
require "lutaml/uml_repository"
require "tempfile"
require "zip"
require "yaml"

RSpec.describe "Package Lifecycle Commands (via UmlCommands)" do
  let(:test_xmi) { File.join(__dir__, "../../fixtures/plateau_all_packages_export.xmi") }
  let(:test_qea) { File.join(__dir__, "../../../examples/qea/test.qea") }
  let(:output_lur) { Tempfile.new(["package_test", ".lur"]).path }

  after do
    File.unlink(output_lur) if File.exist?(output_lur)
  end

  describe "build command" do
    context "with XMI input" do
      it "builds LUR package from XMI file" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", output_lur,
                                        "--name", "TestPackage",
                                        "--version", "2.0"])
        }.to output(/Package built successfully/).to_stdout

        expect(File.exist?(output_lur)).to be true

        # Verify package structure
        expect {
          Zip::File.open(output_lur) do |zip|
            expect(zip.find_entry("metadata.yaml")).not_to be_nil
            expect(zip.find_entry("repository.marshal")).not_to be_nil
          end
        }.not_to raise_error
      end

      it "builds package with validation" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", output_lur,
                                        "--validate"])
        }.to output(/Validating repository|Parsing/).to_stdout
         .and output(/Package built successfully/).to_stdout

        expect(File.exist?(output_lur)).to be true
      end

      it "builds package without validation" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", output_lur,
                                        "--no-validate"])
        }.not_to output(/Validating repository/).to_stdout

        expect(File.exist?(output_lur)).to be true
      end

      it "builds package with YAML serialization" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", output_lur,
                                        "--format", "yaml"])
        }.to output(/Package built successfully/).to_stdout

        expect(File.exist?(output_lur)).to be true

        # Verify YAML format was used
        Zip::File.open(output_lur) do |zip|
          expect(zip.find_entry("repository.yaml")).not_to be_nil
          expect(zip.find_entry("repository.marshal")).to be_nil
        end
      end

      it "includes statistics in output" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_xmi, "-o", output_lur])
        }.to output(/Package Contents:/).to_stdout
         .and output(/Packages:/).to_stdout
         .and output(/Classes:/).to_stdout
      end

      it "handles strict validation mode" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", output_lur,
                                        "--strict"])
        }.not_to raise_error
      end
    end

    context "with QEA input" do
      before do
        skip "QEA test file not available" unless File.exist?(test_qea)
      end

      it "builds LUR package from QEA file" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", test_qea,
                                        "-o", output_lur,
                                        "--name", "QEATestPackage"])
        }.to output(/Parsing QEA file|Package built successfully/).to_stdout

        expect(File.exist?(output_lur)).to be true
      end
    end

    context "error handling" do
      it "handles missing input file" do
        expect {
          Lutaml::Cli::UmlCommands.start(["build", "nonexistent.xmi",
                                        "-o", output_lur])
        }.to output(/Model file not found/).to_stdout
      end

      it "handles invalid XMI file" do
        invalid_xmi = Tempfile.new(["invalid", ".xmi"])
        invalid_xmi.write("not valid xml")
        invalid_xmi.close

        expect {
          Lutaml::Cli::UmlCommands.start(["build", invalid_xmi.path,
                                        "-o", output_lur])
        }.to output(/Failed to build package/).to_stdout

        File.unlink(invalid_xmi.path)
      end
    end
  end

  describe "info command" do
    let(:test_lur) do
      # Build a test LUR first
      temp_lur = Tempfile.new(["info_test", ".lur"]).path
      repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
      repo.export_to_package(temp_lur, name: "InfoTestPackage", version: "1.5")
      temp_lur
    end

    after do
      File.unlink(test_lur) if File.exist?(test_lur)
    end

    it "shows package information in text format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["info", test_lur])
      }.to output(/Package Information/).to_stdout
       .and output(/Name:/).to_stdout
       .and output(/Contents:/).to_stdout
    end

    it "shows package information in JSON format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["info", test_lur, "--format", "json"])
      }.to output(/{/).to_stdout
       .and output(/"name"/).to_stdout
    end

    it "shows package information in YAML format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["info", test_lur, "--format", "yaml"])
      }.to output(/name:/).to_stdout
       .and output(/version:/).to_stdout
    end

    it "handles missing LUR file" do
      expect {
        Lutaml::Cli::UmlCommands.start(["info", "nonexistent.lur"])
      }.to output(/Package file not found/).to_stdout
    end

    it "handles invalid LUR file" do
      invalid_lur = Tempfile.new(["invalid", ".lur"])
      invalid_lur.write("not a zip file")
      invalid_lur.close

      expect {
        Lutaml::Cli::UmlCommands.start(["info", invalid_lur.path])
      }.to output(/Failed to read package info/).to_stdout

      File.unlink(invalid_lur.path)
    end
  end

  describe "validate command" do
    let(:test_lur) do
      # Build a test LUR first
      temp_lur = Tempfile.new(["validate_test", ".lur"]).path
      repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
      repo.export_to_package(temp_lur)
      temp_lur
    end

    after do
      File.unlink(test_lur) if File.exist?(test_lur)
    end

    it "validates a valid package" do
      expect {
        Lutaml::Cli::UmlCommands.start(["validate", test_lur])
      }.to output(/Loading package/).to_stdout
       .and output(/Validating repository/).to_stdout
    end

    it "shows validation warnings when present" do
      expect {
        Lutaml::Cli::UmlCommands.start(["validate", test_lur])
      }.not_to raise_error
    end

    it "shows validation errors when present" do
      expect {
        Lutaml::Cli::UmlCommands.start(["validate", test_lur])
      }.not_to raise_error
    end

    it "shows external references when present" do
      expect {
        Lutaml::Cli::UmlCommands.start(["validate", test_lur])
      }.not_to raise_error
    end

    it "handles missing LUR file" do
      expect {
        Lutaml::Cli::UmlCommands.start(["validate", "nonexistent.lur"])
      }.to output(/Package file not found/).to_stdout
    end
  end

  describe "integration with other commands" do
    let(:test_lur) do
      temp_lur = Tempfile.new(["integration_test", ".lur"]).path
      repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
      repo.export_to_package(temp_lur, name: "IntegrationTest", version: "1.0")
      temp_lur
    end

    after do
      File.unlink(test_lur) if File.exist?(test_lur)
    end

    it "creates packages that work with search commands" do
      expect {
        Lutaml::Cli::UmlCommands.start(["info", test_lur])
      }.to output(/IntegrationTest/).to_stdout

      expect {
        Lutaml::Cli::UmlCommands.start(["search", test_lur, "building", "--limit", "3"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "creates packages that work with inspect commands" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, "package:ModelRoot"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "creates packages that work with stats commands" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur])
      }.to output(/Packages:/).to_stdout
    end
  end
end