# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/uml_commands"
require_relative "../../../lib/lutaml/uml_repository/repository"
require "json"

RSpec.describe "Inspect/Show Commands (via UmlCommands)" do
  let(:test_xmi) { File.join(__dir__, "../../../examples/xmi/basic.xmi") }
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
  let(:test_lur) do
    path = temp_lur_path(prefix: "show_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "inspect command for classes" do
    before do
      skip "No suitable class found in test data" unless sample_class_id
    end

    it "shows class details in text format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_class_id])
      end.to output(/Class:|Name:/).to_stdout
    end

    it "shows class details in JSON format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_class_id,
                                        "--format",
                                        "json"])
      end.to output(/{/).to_stdout
    end

    it "shows class details in YAML format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_class_id,
                                        "--format",
                                        "yaml"])
      end.to output(/name:/).to_stdout
    end
  end

  describe "inspect command for packages" do
    it "shows package details for root" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_package_id])
      end.to output(/Package:|Name:/).to_stdout
    end

    it "shows package details in JSON format" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_package_id,
                                        "--format",
                                        "json"])
      end.to output(/{/).to_stdout
    end
  end

  describe "inspect command for attributes" do
    let(:sample_attribute_id) do
      # Search for an attribute to get a real identifier
      results = test_repo.search("attribute", types: [:attribute])
      attributes = results[:attributes] || []

      if attributes.any?
        result = attributes.first
        "attribute:#{result.qualified_name}"
      end
    end

    before do
      skip "No attributes found in test data" unless sample_attribute_id
    end

    it "shows attribute details" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_attribute_id])
      end.to output(/Attribute:|Name:/).to_stdout
    end
  end

  describe "inspect command error handling" do
    it "handles missing LUR file gracefully" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        "nonexistent.lur",
                                        "class:Test"])
      end.to output(/Failed to load repository|not found/).to_stdout
    end

    it "handles non-existent elements" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        "class:NonExistentClass"])
      end.to output(/Element not found/).to_stdout
    end

    it "handles invalid element identifiers" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        "invalid_format"])
      end.to output(/Element not found|Invalid/).to_stdout
    end
  end

  describe "inspect with include options" do
    before do
      skip "No suitable class found in test data" unless sample_class_id
    end

    it "includes attributes when requested" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_class_id,
                                        "--include",
                                        "attributes"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "includes associations when requested" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_class_id,
                                        "--include",
                                        "associations"])
      end.not_to output(/ERROR/).to_stdout
    end

    it "includes operations when requested" do
      expect do
        Lutaml::Cli::UmlCommands.start(["inspect",
                                        test_lur,
                                        sample_class_id,
                                        "--include",
                                        "operations"])
      end.not_to output(/ERROR/).to_stdout
    end
  end
end
