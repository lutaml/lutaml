# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/parser"
require_relative "../../../../lib/lutaml/cli/uml/verify_command"
require_relative "../../../../lib/lutaml/cli/uml_commands"

RSpec.describe Lutaml::Cli::Uml::VerifyCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/test.xmi") }
  let(:test_qea) { File.join(__dir__, "../../../../examples/qea/test.qea") }
  let(:command) { described_class.new(options) }

  describe "#run" do
    let(:options) { { format: "text" } }

    context "error handling" do
      it "handles missing XMI file" do
        expect do
          command.run("nonexistent.xmi", test_qea)
        end.to raise_error(/XMI file not found/)
      end

      it "handles missing QEA file" do
        expect do
          command.run(test_xmi, "nonexistent.qea")
        end.to raise_error(/QEA file not found/)
      end
    end

    context "with valid files" do
      it "performs verification when files exist" do
        unless File.exist?(test_xmi) && File.exist?(test_qea)
          skip "Test files not available"
        end
        expect do
          command.run(test_xmi, test_qea)
        end.to output(/Verification/).to_stdout
      end
    end
  end
end
