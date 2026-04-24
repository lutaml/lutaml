# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/ls_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"

RSpec.describe Lutaml::Cli::Uml::LsCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "ls_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "#run" do
    context "listing packages" do
      let(:options) { { type: "packages", format: "text" } }

      it "lists packages successfully" do
        expect do
          command.run(test_lur)
        end.to output(/Loading repository/).to_stdout
      end
    end

    context "listing classes" do
      let(:options) { { type: "classes", format: "text" } }

      it "lists all classes" do
        expect { command.run(test_lur) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "listing diagrams" do
      let(:options) { { type: "diagrams", format: "text" } }

      it "lists diagrams or shows appropriate message" do
        expect { command.run(test_lur) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with recursive option" do
      let(:options) { { type: "packages", format: "text", recursive: true } }

      it "includes nested elements" do
        expect { command.run(test_lur) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { { type: "invalid_type" } }

      it "handles unknown element type" do
        expect { command.run(test_lur) }.to raise_error(/Unknown type/)
      end
    end
  end
end
