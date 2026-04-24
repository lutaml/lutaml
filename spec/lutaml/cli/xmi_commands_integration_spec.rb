# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/uml_commands"
require_relative "../../../lib/lutaml/uml_repository/repository"
require "json"
require "yaml"

RSpec.describe "UmlCommands Integration Tests" do
  let(:test_xmi) { File.join(__dir__, "../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "integration_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "build -> info workflow" do
    it "builds a package and retrieves its info" do
      workflow_lur = temp_lur_path(prefix: "workflow_test")

      # Build package
      expect do
        Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", workflow_lur,
                                        "--name", "WorkflowTest"])
      end.to output(/Package built successfully/).to_stdout
      expect(File.exist?(workflow_lur)).to be true

      # Get info
      expect do
        Lutaml::Cli::UmlCommands.start(["info", workflow_lur])
      end.to output(/WorkflowTest/).to_stdout
      expect do
        Lutaml::Cli::UmlCommands.start(["info", workflow_lur])
      end.to output(/Package Information/).to_stdout

      FileUtils.rm_f(workflow_lur)
    end
  end

  describe "build -> validate workflow" do
    it "builds and validates a package" do
      validate_lur = temp_lur_path(prefix: "validate_workflow")

      # Build
      expect do
        Lutaml::Cli::UmlCommands.start(["build", test_xmi, "-o", validate_lur])
      end.to output(/Package built successfully/).to_stdout

      # Validate
      expect do
        Lutaml::Cli::UmlCommands.start(["validate", validate_lur])
      end.to output(/Validating repository/).to_stdout

      FileUtils.rm_f(validate_lur)
    end
  end

  describe "build -> search workflow" do
    it "builds a package and searches it" do
      # Search in pre-built package
      expect do
        Lutaml::Cli::UmlCommands.start(["search", test_lur, "building",
                                        "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end
  end

  describe "build -> inspect workflow" do
    it "builds a package and inspects elements" do
      # Inspect package
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur,
                                        "package:ModelRoot"])
      end.not_to output(/ERROR/).to_stdout
    end
  end

  describe "build -> stats workflow" do
    it "builds a package and displays statistics" do
      expect do
        Lutaml::Cli::UmlCommands.start(["stats", test_lur])
      end.to output(/Packages:/).to_stdout
      expect do
        Lutaml::Cli::UmlCommands.start(["stats", test_lur])
      end.to output(/Classes:/).to_stdout
    end
  end

  describe "build -> tree workflow" do
    it "builds a package and displays tree" do
      expect do
        Lutaml::Cli::UmlCommands.start(["tree", test_lur])
      end.not_to output(/ERROR/).to_stdout
    end
  end

  describe "build -> export workflow" do
    it "builds a package and exports it" do
      export_file = temp_lur_path(prefix: "export_test").sub(/\.lur$/, ".json")

      expect do
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                        "--format", "json",
                                        "-o", export_file])
      end.to output(/Exported to/).to_stdout
      expect(File.exist?(export_file)).to be true

      FileUtils.rm_f(export_file)
    end
  end

  describe "ls command variations" do
    it "lists packages" do
      expect do
        Lutaml::Cli::UmlCommands.start(["ls", test_lur])
      end.not_to output(/ERROR/).to_stdout
    end

    it "lists classes" do
      expect do
        Lutaml::Cli::UmlCommands.start(["ls", test_lur, "--type",
                                        "classes"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "lists diagrams" do
      expect do
        Lutaml::Cli::UmlCommands.start(["ls", test_lur, "--type",
                                        "diagrams"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "lists all elements" do
      expect do
        Lutaml::Cli::UmlCommands.start(["ls", test_lur, "--type", "all"])
      end.not_to output(/ERROR/).to_stdout
    end
  end

  describe "find command variations" do
    it "finds by stereotype" do
      expect do
        Lutaml::Cli::UmlCommands.start(["find", test_lur, "--stereotype",
                                        "interface"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "finds by package" do
      expect do
        Lutaml::Cli::UmlCommands.start(["find", test_lur, "--package",
                                        "ModelRoot"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "finds by pattern" do
      expect do
        Lutaml::Cli::UmlCommands.start(["find", test_lur, "--pattern",
                                        "^Building"])
      end.not_to output(/ERROR/).to_stdout
    end
  end

  describe "output format consistency" do
    it "supports text format across commands" do
      commands = [
        ["stats", test_lur],
        ["tree", test_lur],
        ["ls", test_lur],
      ]

      commands.each do |cmd|
        expect do
          Lutaml::Cli::UmlCommands.start(cmd)
        end.not_to output(/ERROR/).to_stdout
      end
    end

    it "supports JSON format across commands" do
      commands = [
        ["stats", test_lur, "--format", "json"],
        ["tree", test_lur, "--format", "json"],
        ["ls", test_lur, "--format", "json"],
      ]

      commands.each do |cmd|
        expect do
          Lutaml::Cli::UmlCommands.start(cmd)
        end.to output(/{|\[/).to_stdout
      end
    end

    it "supports YAML format across commands" do
      commands = [
        ["stats", test_lur, "--format", "yaml"],
        ["tree", test_lur, "--format", "yaml"],
        ["ls", test_lur, "--format", "yaml"],
      ]

      commands.each do |cmd|
        expect do
          Lutaml::Cli::UmlCommands.start(cmd)
        end.not_to output(/ERROR/).to_stdout
      end
    end
  end

  describe "error handling across commands" do
    it "handles missing files consistently" do
      commands = [
        ["info", "nonexistent.lur"],
        ["validate", "nonexistent.lur"],
        ["stats", "nonexistent.lur"],
        ["search", "nonexistent.lur", "test"],
      ]

      commands.each do |cmd|
        expect do
          Lutaml::Cli::UmlCommands.start(cmd)
        end.to output(/not found|Failed to load/).to_stdout
      end
    end
  end

  describe "complex workflows" do
    it "builds, validates, searches, and exports" do
      complex_lur = temp_lur_path(prefix: "complex_workflow")
      export_file = temp_lur_path(prefix: "complex_export").sub(/\.lur$/, ".json")

      # Build
      expect do
        Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                        "-o", complex_lur,
                                        "--validate"])
      end.to output(/Package built successfully/).to_stdout

      # Search
      expect do
        Lutaml::Cli::UmlCommands.start(["search",
                                        complex_lur, "building", "--limit", "3"])
      end.not_to output(/ERROR/).to_stdout

      # Export
      expect do
        Lutaml::Cli::UmlCommands.start(["export", complex_lur,
                                        "--format", "json",
                                        "-o", export_file])
      end.to output(/Exported to/).to_stdout
      expect(File.exist?(export_file)).to be true

      FileUtils.rm_f(complex_lur)
      FileUtils.rm_f(export_file)
    end
  end
end
