# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/build_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::BuildCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:output_lur) { Tempfile.new(["build_test", ".lur"]) }
  let(:command) { described_class.new(options) }

  after do
    output_lur.unlink if File.exist?(output_lur.path)
  end

  describe "#run" do
    context "with XMI input" do
      let(:options) do
        { output: output_lur.path, name: "TestPackage", version: "1.0" }
      end

      it "builds LUR package successfully" do
        expect do
          command.run(test_xmi)
        end.to output(/Package built successfully/).to_stdout
        expect(File.exist?(output_lur.path)).to be true
      end

      it "displays package statistics" do
        expect do
          command.run(test_xmi)
        end.to output(/Package Contents:/).to_stdout
      end
    end

    context "with validation enabled" do
      let(:options) { { output: output_lur.path, validate: true } }

      it "validates before building" do
        expect do
          command.run(test_xmi)
        end.to output(/Validating repository/).to_stdout
      end
    end

    context "with validation disabled" do
      let(:options) { { output: output_lur.path, validate: false } }

      it "skips validation" do
        expect do
          command.run(test_xmi)
        end.not_to output(/Validating repository/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { { output: output_lur.path } }

      it "handles missing input file" do
        expect do
          command.run("nonexistent.xmi")
        end.to raise_error(/Model file not found/)
      end
    end
  end
end