# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/inspect_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::InspectCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["inspect_test", ".lur"])
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur.path)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    test_lur.unlink if File.exist?(test_lur.path)
  end

  describe "#run" do
    context "inspecting package" do
      let(:options) { { format: "text" } }

      it "displays package details" do
        expect do
          command.run(test_lur.path, "package:ModelRoot")
        end.not_to output(/ERROR/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs JSON format" do
        expect do
          command.run(test_lur.path, "package:ModelRoot")
        end.to output(/{/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles non-existent element" do
        expect do
          command.run(test_lur.path,
                      "class:NonExistent")
        end.to raise_error(/Element not found/)
      end
    end
  end
end