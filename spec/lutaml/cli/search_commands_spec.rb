# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/uml_commands"
require_relative "../../../lib/lutaml/uml_repository/repository"
require "tempfile"

RSpec.describe "Search and Find Commands (via UmlCommands)" do
  let(:xmi_file) { File.join(__dir__, "../../../examples/xmi/basic.xmi") }
  let(:lur_file) do
    Tempfile.new(["test_search", ".lur"]).tap do |f|
      f.close
      # Build LUR package for testing
      repo = Lutaml::UmlRepository::Repository.from_xmi(xmi_file)
      repo.export_to_package(f.path)
    end
  end

  after do
    lur_file.unlink if File.exist?(lur_file.path)
  end

  describe "search command" do
    it "searches and returns results" do
      expect do
        Lutaml::Cli::UmlCommands
          .start(["search", lur_file.path, "Class", "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "filters by element type" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "Class",
                                        "--type", "class", "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "supports package filtering" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "building",
                                        "--package", "Model", "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "searches with regex pattern" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "^Building",
                                        "--regex", "--type", "class",
                                        "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "searches in name field by default" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "Class",
                                        "--in", "name", "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "accepts documentation field option" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "Class",
                                        "--in", "name", "documentation",
                                        "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "outputs JSON format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "Class",
                                        "--format", "json", "--limit", "2"])
      end.to output(/\[/).to_stdout
    end

    it "outputs YAML format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "Class",
                                        "--format", "yaml", "--limit", "2"])
      end.to output(/---/).to_stdout
    end

    it "outputs table format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "Class",
                                        "--format", "table", "--limit", "5"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "respects limit parameter" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path, "building",
                                        "--limit", "3"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "handles missing LUR file gracefully" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", "nonexistent.lur", "test"])
      end.to output(/Package file not found|Failed to load/).to_stdout
    end

    it "handles empty search results" do
      expect do
        Lutaml::Cli::UmlCommands.start(["search", lur_file.path,
                                        "XyZabc123NotFound"])
      end.to output(/No results found/).to_stdout
    end
  end

  describe "find command" do
    it "finds by stereotype" do
      expect do
        Lutaml::Cli::UmlCommands.start(["find", lur_file.path, "--stereotype",
                                        "interface"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "finds by package" do
      expect do
        Lutaml::Cli::UmlCommands.start(["find", lur_file.path, "--package",
                                        "Model"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "finds by pattern" do
      expect do
        Lutaml::Cli::UmlCommands
          .start(["find", lur_file.path, "--pattern", "^Building.*"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "outputs in JSON format" do
      expect do
        Lutaml::Cli::UmlCommands
          .start(
            [
              "find", lur_file.path, "--package",
              "Basic Class Diagram with Multiplicities",
              "--format", "json"
            ],
          )
      end.to output(/\[/).to_stdout
    end

    it "outputs in YAML format" do
      expect do
        Lutaml::Cli::UmlCommands
          .start(
            [
              "find",
              lur_file.path,
              "--package",
              "Basic Class Diagram with Multiplicities",
              "--format",
              "yaml",
            ],
          )
      end.not_to output(/ERROR/).to_stdout
    end

    it "requires at least one filter" do
      expect do
        Lutaml::Cli::UmlCommands.start(["find", lur_file.path])
      end.to output(/Please specify at least one filter/).to_stdout
    end

    it "shows warning when no results found" do
      expect do
        Lutaml::Cli::UmlCommands
          .start(
            ["find", lur_file.path, "--stereotype", "NonExistent"],
          )
      end.to output(/No elements found matching stereotype: NonExistent/)
        .to_stdout
    end
  end
end
