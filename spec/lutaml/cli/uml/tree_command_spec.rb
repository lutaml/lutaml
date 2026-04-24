# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/tree_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
RSpec.describe Lutaml::Cli::Uml::TreeCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "tree_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "#run" do
    context "displaying tree structure" do
      let(:options) { { format: "text", show_counts: true } }

      it "displays package tree" do
        expect { command.run(test_lur) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with depth limit" do
      let(:options) { { format: "text", depth: 2 } }

      it "respects depth limit" do
        expect { command.run(test_lur) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs JSON format" do
        expect { command.run(test_lur) }.to output(/{/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles non-existent package" do
        expect do
          command.run(test_lur,
                      "NonExistent::Package")
        end.to raise_error(/Package not found/)
      end
    end
  end
end
