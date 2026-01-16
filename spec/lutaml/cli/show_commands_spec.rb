# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/uml_commands"
require_relative "../../../lib/lutaml/uml_repository/repository"
require "tempfile"
require "json"

RSpec.describe "Inspect/Show Commands (via UmlCommands)" do
  let(:test_xmi) { File.join(__dir__, "../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    Tempfile.new(["show_test", ".lur"]).tap do |f|
      f.close
      # Build LUR package for testing
      repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
      repo.export_to_package(f.path)
    end.path
  end

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  # Helper to find real elements from the test data
  let(:test_repo) { Lutaml::UmlRepository::Repository.from_package(test_lur) }

  let(:sample_class_id) do
    # Get a real class identifier
    classes = test_repo.all_classes
    if classes.any?
      qname = test_repo.qualified_name_for(classes.first)
      "class:#{qname}"
    end
  end

  let(:sample_package_id) do
    "package:ModelRoot"
  end

  describe "inspect command for classes" do
    before do
      skip "No suitable class found in test data" unless sample_class_id
    end

    it "shows class details in text format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_class_id])
      }.to output(/Class:|Name:/).to_stdout
    end

    it "shows class details in JSON format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_class_id,
                                      "--format", "json"])
      }.to output(/{/).to_stdout
    end

    it "shows class details in YAML format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_class_id,
                                      "--format", "yaml"])
      }.to output(/name:/).to_stdout
    end
  end

  describe "inspect command for packages" do
    it "shows package details for root" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_package_id])
      }.to output(/Package:|Name:/).to_stdout
    end

    it "shows package details in JSON format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_package_id,
                                      "--format", "json"])
      }.to output(/{/).to_stdout
    end
  end

  describe "inspect command for attributes" do
    let(:sample_attribute_id) do
      # Search for an attribute to get a real identifier
      results = test_repo.search("road", types: [:attribute])
      attributes = results[:attributes] || []

      if attributes.any?
        attr = attributes.first
        if attr.respond_to?(:owner)
          class_qname = test_repo.qualified_name_for(attr.owner)
        end
        if class_qname && attr.respond_to?(:name)
          "attribute:#{class_qname}::#{attr.name}"
        end
      end
    end

    before do
      skip "No suitable attribute found in test data" unless sample_attribute_id
    end

    it "shows attribute details" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur,
sample_attribute_id])
      }.to output(/Attribute:|Name:/).to_stdout
    end
  end

  describe "inspect command error handling" do
    it "handles missing LUR file gracefully" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", "nonexistent.lur",
"class:Test"])
      }.to output(/Failed to load repository|not found/).to_stdout
    end

    it "handles non-existent elements" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur,
"class:NonExistentClass"])
      }.to output(/Element not found/).to_stdout
    end

    it "handles invalid element identifiers" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, "invalid_format"])
      }.to output(/Element not found|Invalid/).to_stdout
    end
  end

  describe "inspect with include options" do
    before do
      skip "No suitable class found in test data" unless sample_class_id
    end

    it "includes attributes when requested" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_class_id,
                                      "--include", "attributes"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "includes associations when requested" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_class_id,
                                      "--include", "associations"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "includes operations when requested" do
      expect {
        Lutaml::Cli::UmlCommands.start(["inspect", test_lur, sample_class_id,
                                      "--include", "operations"])
      }.not_to output(/ERROR/).to_stdout
    end
  end
end