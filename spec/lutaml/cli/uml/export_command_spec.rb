# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/export_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::ExportCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["export_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:output_file) { Tempfile.new(["export_output", ".csv"]).path }
  let(:command) { described_class.new(options) }

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
    File.unlink(output_file) if File.exist?(output_file)
  end

  describe "#run" do
    context "exporting to JSON" do
      let(:output_json) { Tempfile.new(["export_output", ".json"]).path }
      let(:options) { { format: "json", output: output_json } }

      after do
        File.unlink(output_json) if File.exist?(output_json)
      end

      it "exports to JSON format" do
        expect { command.run(test_lur) }.to output(/Exported to/).to_stdout
        expect(File.exist?(output_json)).to be true
      end
    end

    context "error handling" do
      let(:options) { { format: "csv", output: output_file } }

      it "exports successfully" do
        expect { command.run(test_lur) }.to raise_error(/Unknown format/)
      end
    end
  end
end