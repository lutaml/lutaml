# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/uml_commands"
require_relative "../../../lib/lutaml/uml_repository/repository"
require "tmpdir"

RSpec.describe "Diagram Commands (via UmlCommands)" do
  let(:fixture_path) { File.join(__dir__, "../../fixtures") }
  let(:temp_dir) { Dir.mktmpdir }
  let(:lur_path) { File.join(temp_dir, "test.lur") }

  # Create a test LUR package before each test
  before do
    # Create a simple test document with diagrams
    document = Lutaml::Uml::Document.new
    document.name = "TestModel"

    # Create a root package
    root_package = Lutaml::Uml::Package.new
    root_package.name = "ModelRoot"
    root_package.xmi_id = "root_pkg"

    # Create a sub-package
    sub_package = Lutaml::Uml::Package.new
    sub_package.name = "SubPackage"
    sub_package.xmi_id = "sub_pkg"

    # Create diagrams
    diagram1 = Lutaml::Uml::Diagram.new
    diagram1.name = "Class Diagram 1"
    diagram1.xmi_id = "diag1"
    diagram1.package_id = root_package.xmi_id
    diagram1.package_name = root_package.name

    diagram2 = Lutaml::Uml::Diagram.new
    diagram2.name = "Sequence Diagram"
    diagram2.xmi_id = "diag2"
    diagram2.package_id = root_package.xmi_id
    diagram2.package_name = root_package.name

    diagram3 = Lutaml::Uml::Diagram.new
    diagram3.name = "Package Diagram"
    diagram3.xmi_id = "diag3"
    diagram3.package_id = sub_package.xmi_id
    diagram3.package_name = sub_package.name

    # Add diagrams to packages
    root_package.diagrams = [diagram1, diagram2]
    sub_package.diagrams = [diagram3]

    root_package.packages = [sub_package]
    document.packages = [root_package]

    # Build repository and export
    repo = Lutaml::UmlRepository::Repository.new(document: document)
    repo.export_to_package(lur_path)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "ls command with --type diagrams" do
    it "lists diagrams or shows appropriate message" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", lur_path, "--type", "diagrams"])
      }.not_to raise_error
    end

    it "handles JSON format for diagrams" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", lur_path, "--type", "diagrams",
                                      "--format", "json"])
      }.to output(/\[/).to_stdout
    end

    it "handles YAML format for diagrams" do
      expect {
        Lutaml::Cli::UmlCommands.start(["ls", lur_path, "--type", "diagrams",
                                      "--format", "yaml"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "shows warning when no diagrams found" do
      # Create empty LUR
      empty_lur = File.join(temp_dir, "empty.lur")
      empty_doc = Lutaml::Uml::Document.new
      empty_doc.name = "Empty"
      empty_pkg = Lutaml::Uml::Package.new
      empty_pkg.name = "ModelRoot"
      empty_pkg.xmi_id = "empty_root"
      empty_doc.packages = [empty_pkg]
      empty_repo = Lutaml::UmlRepository::Repository.new(document: empty_doc)
      empty_repo.export_to_package(empty_lur)

      expect {
        Lutaml::Cli::UmlCommands.start(["ls", empty_lur, "--type", "diagrams"])
      }.to output(/No diagrams found/).to_stdout
    end
  end

  # describe "inspect command for diagrams" do
  #   it "shows diagram details using diagram identifier" do
  #     # For now, inspect may need diagram:name format
  #     expect {
  #       Lutaml::Cli::UmlCommands.start(["inspect", lur_path, "diagram:diag1"])
  #     }.to output(/Class Diagram 1|diag1/).to_stdout
  #   end
  # end

  # describe "tree command showing diagram counts" do
  #   it "displays package tree with diagram counts" do
  #     expect {
  #       Lutaml::Cli::UmlCommands.start(["tree", lur_path, "--show-counts"])
  #     }.not_to output(/ERROR/).to_stdout
  #   end
  # end

  # describe "stats command for diagram statistics" do
  #   it "shows diagram statistics" do
  #     expect {
  #       Lutaml::Cli::UmlCommands.start(["stats", lur_path])
  #     }.to output(/Diagrams:/).to_stdout
  #      .and output(/3/).to_stdout
  #   end

  #   it "shows statistics in JSON format" do
  #     expect {
  #       Lutaml::Cli::UmlCommands
  #         .start(["stats", lur_path, "--format", "json"])
  #     }.to output(/{/).to_stdout
  #      .and output(/"total_diagrams"/).to_stdout
  #   end
  # end
end
