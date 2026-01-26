# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/tree_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::TreeCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["tree_test", ".lur"])
    temp_lur.close
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur.path)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    if File.exist?(test_lur.path)
      begin
        test_lur.close if !test_lur.closed?
        test_lur.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "#run" do
    context "displaying tree structure" do
      let(:options) { { format: "text", show_counts: true } }

      it "displays package tree" do
        expect { command.run(test_lur.path) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with depth limit" do
      let(:options) { { format: "text", depth: 2 } }

      it "respects depth limit" do
        expect { command.run(test_lur.path) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs JSON format" do
        expect { command.run(test_lur.path) }.to output(/{/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles non-existent package" do
        expect do
          command.run(test_lur.path,
                      "NonExistent::Package")
        end.to raise_error(/Package not found/)
      end
    end
  end
end