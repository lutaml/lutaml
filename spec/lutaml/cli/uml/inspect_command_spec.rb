# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/inspect_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
RSpec.describe Lutaml::Cli::Uml::InspectCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "inspect_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "#run" do
    context "inspecting package" do
      let(:options) { { format: "text" } }

      it "displays package details" do
        expect do
          command.run(test_lur, "package:ModelRoot")
        end.not_to output(/ERROR/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs JSON format" do
        expect do
          command.run(test_lur, "package:ModelRoot")
        end.to output(/{/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles non-existent element" do
        expect do
          command.run(test_lur,
                      "class:NonExistent")
        end.to raise_error(/Element not found/)
      end
    end
  end
end
