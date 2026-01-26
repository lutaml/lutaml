# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/stats_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::StatsCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["stats_test", ".lur"])
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur.path)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    test_lur.close! if File.exist?(test_lur.path)
  end

  describe "#run" do
    context "with text format" do
      let(:options) { { format: "text" } }

      it "displays statistics" do
        expect { command.run(test_lur.path) }.to output(/Packages:/).to_stdout
      end
    end

    context "with detailed option" do
      let(:options) { { format: "text", detailed: true } }

      it "shows detailed statistics" do
        expect { command.run(test_lur.path) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs JSON format" do
        expect { command.run(test_lur.path) }.to output(/{/).to_stdout
      end
    end
  end
end