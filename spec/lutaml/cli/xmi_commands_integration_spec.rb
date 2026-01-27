# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/uml_commands"
require_relative "../../../lib/lutaml/uml_repository/repository"
require "tempfile"
require "json"
require "yaml"

RSpec.describe "UmlCommands Integration Tests" do
  let(:test_xmi) { File.join(__dir__, "../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["integration_test", ".lur"])
    # Build LUR package for testing
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    temp_lur.close
    repo.export_to_package(temp_lur.path)
    temp_lur
  end

  after do
    if File.exist?(test_lur.path)
      begin
        test_lur.close if !test_lur.closed?
        test_lur.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "build -> info workflow" do
    it "builds a package and retrieves its info" do
      temp_lur = Tempfile.new(["workflow_test", ".lur"])
      temp_lur.close

      # Build package
      expect {
        Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                      "-o", temp_lur.path,
                                      "--name", "WorkflowTest"])
      }.to output(/Package built successfully/).to_stdout
      expect(File.exist?(temp_lur.path)).to be true

      # Get info
      expect {
        Lutaml::Cli::UmlCommands.start(["info", temp_lur.path])
      }.to output(/WorkflowTest/).to_stdout
      expect {
        Lutaml::Cli::UmlCommands.start(["info", temp_lur.path])
      }.to output(/Package Information/).to_stdout

      begin
        temp_lur.close if !temp_lur.closed?
        temp_lur.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "build -> validate workflow" do
    it "builds and validates a package" do
      temp_lur = Tempfile.new(["validate_workflow", ".lur"])
      temp_lur.close

      # Build
      expect {
        Lutaml::Cli::UmlCommands.start(["build", test_xmi, "-o", temp_lur.path])
      }.to output(/Package built successfully/).to_stdout

      # Validate
      expect {
        Lutaml::Cli::UmlCommands.start(["validate", temp_lur.path])
      }.to output(/Validating repository/).to_stdout

      begin
        temp_lur.close if !temp_lur.closed?
        temp_lur.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "build -> search workflow" do
    it "builds a package and searches it" do
      # Search in pre-built package
      expect {
        Lutaml::Cli::UmlCommands.start(["search", test_lur.path, "building",
"--limit", "5"])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "build -> inspect workflow" do
    it "builds a package and inspects elements" do
      # Inspect package
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur.path,
"package:ModelRoot"])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "build -> stats workflow" do
    it "builds a package and displays statistics" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur.path])
      }.to output(/Packages:/).to_stdout
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur.path])
      }.to output(/Classes:/).to_stdout
    end
  end

  describe "build -> tree workflow" do
    it "builds a package and displays tree" do
      expect {
        Lutaml::Cli::UmlCommands.start(["tree", test_lur.path])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "build -> export workflow" do
    it "builds a package and exports it" do
      export_file = Tempfile.new(["export_test", ".json"])
      export_file.close

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur.path,
                                      "--format", "json",
                                      "-o", export_file.path])
      }.to output(/Exported to/).to_stdout
      expect(File.exist?(export_file.path)).to be true

      begin
        export_file.close if !export_file.closed?
        export_file.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "ls command variations" do
    it "lists packages" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", test_lur.path])
      }.not_to output(/ERROR/).to_stdout
    end

    it "lists classes" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", test_lur.path, "--type",
"classes"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "lists diagrams" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", test_lur.path, "--type",
"diagrams"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "lists all elements" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", test_lur.path, "--type", "all"])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "find command variations" do
    it "finds by stereotype" do
      expect {
        Lutaml::Cli::UmlCommands.start(["find", test_lur.path, "--stereotype",
"interface"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "finds by package" do
      expect {
        Lutaml::Cli::UmlCommands.start(["find", test_lur.path, "--package",
"ModelRoot"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "finds by pattern" do
      expect {
        Lutaml::Cli::UmlCommands.start(["find", test_lur.path, "--pattern",
"^Building"])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "output format consistency" do
    it "supports text format across commands" do
      commands = [
        ["stats", test_lur.path],
        ["tree", test_lur.path],
        ["ls", test_lur.path]
      ]

      commands.each do |cmd|
        expect {
          Lutaml::Cli::UmlCommands.start(cmd)
        }.not_to output(/ERROR/).to_stdout
      end
    end

    it "supports JSON format across commands" do
      commands = [
        ["stats", test_lur.path, "--format", "json"],
        ["tree", test_lur.path, "--format", "json"],
        ["ls", test_lur.path, "--format", "json"]
      ]

      commands.each do |cmd|
        expect {
          Lutaml::Cli::UmlCommands.start(cmd)
        }.to output(/{|\[/).to_stdout
      end
    end

    it "supports YAML format across commands" do
      commands = [
        ["stats", test_lur.path, "--format", "yaml"],
        ["tree", test_lur.path, "--format", "yaml"],
        ["ls", test_lur.path, "--format", "yaml"]
      ]

      commands.each do |cmd|
        expect {
          Lutaml::Cli::UmlCommands.start(cmd)
        }.not_to output(/ERROR/).to_stdout
      end
    end
  end

  describe "error handling across commands" do
    it "handles missing files consistently" do
      commands = [
        ["info", "nonexistent.lur"],
        ["validate", "nonexistent.lur"],
        ["stats", "nonexistent.lur"],
        ["search", "nonexistent.lur", "test"]
      ]

      commands.each do |cmd|
        expect {
          Lutaml::Cli::UmlCommands.start(cmd)
        }.to output(/not found|Failed to load/).to_stdout
      end
    end
  end

  describe "complex workflows" do
    it "builds, validates, searches, and exports" do
      temp_lur = Tempfile.new(["complex_workflow", ".lur"])
      export_file = Tempfile.new(["complex_export", ".json"])
      temp_lur.close
      export_file.close

      # Build
      expect {
        Lutaml::Cli::UmlCommands.start(["build", test_xmi,
                                      "-o", temp_lur.path,
                                      "--validate"])
      }.to output(/Package built successfully/).to_stdout

      # Search
      expect {
        Lutaml::Cli::UmlCommands.start(["search",
          temp_lur.path, "building", "--limit", "3"])
      }.not_to output(/ERROR/).to_stdout

      # Export
      expect {
        Lutaml::Cli::UmlCommands.start(["export", temp_lur.path,
                                      "--format", "json",
                                      "-o", export_file.path])
      }.to output(/Exported to/).to_stdout
      expect(File.exist?(export_file.path)).to be true

      if File.exist?(temp_lur.path)
        begin
          temp_lur.close if !temp_lur.closed?
          temp_lur.unlink
        rescue Errno::EACCES
        end
      end

      if File.exist?(export_file.path)
        begin
          export_file.close if !export_file.closed?
          export_file.unlink
        rescue Errno::EACCES
        end
      end
    end
  end

end
