# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/verify_command"

RSpec.describe Lutaml::Cli::Uml::VerifyCommand do
  let(:test_xmi) { File.join(__dir__, "../../../examples/qea/test.xmi") }
  let(:test_qea) { File.join(__dir__, "../../../examples/qea/test.qea") }
  let(:command) { described_class.new(options) }

  describe "#run" do
    let(:options) { { format: "text" } }

    context "error handling" do
      it "handles missing XMI file" do
        expect {
          expect { command.run("nonexistent.xmi", test_qea) }.to raise_error(SystemExit)
        }.to output(/XMI file not found/).to_stdout
      end

      it "handles missing QEA file" do
        skip "XMI file not available" unless File.exist?(test_xmi)
        expect {
          expect { command.run(test_xmi, "nonexistent.qea") }.to raise_error(SystemExit)
        }.to output(/QEA file not found/).to_stdout
      end
    end

    context "with valid files" do
      it "performs verification when files exist" do
        skip "Test files not available" unless File.exist?(test_xmi) && File.exist?(test_qea)
        expect { command.run(test_xmi, test_qea) }.to output(/Verification/).to_stdout
      end
    end
  end
end