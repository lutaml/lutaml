# frozen_string_literal: true

require "spec_helper"
require "lutaml/cli/uml/inspect_command"
require "lutaml/uml_repository"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::InspectCommand do
  let(:test_xmi) { File.join(__dir__, "../../fixtures/plateau_all_packages_export.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["inspect_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  describe "#run" do
    context "inspecting package" do
      let(:options) { { format: "text" } }

      it "displays package details" do
        expect { command.run(test_lur, "package:ModelRoot") }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs JSON format" do
        expect { command.run(test_lur, "package:ModelRoot") }.to output(/{/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles non-existent element" do
        expect { command.run(test_lur, "class:NonExistent") }.to output(/Element not found/).to_stdout
      end
    end
  end
end