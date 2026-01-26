# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/export_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::ExportCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["export_test", ".lur"])
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    temp_lur.close
    repo.export_to_package(temp_lur.path)
    temp_lur
  end
  let(:output_file) { Tempfile.new(["export_output", ".csv"]) }
  let(:command) { described_class.new(options) }

  before do
    output_file.close
  end

  after do
    if File.exist?(test_lur.path)
      begin
        test_lur.close if !test_lur.closed?
        test_lur.unlink
      rescue Errno::EACCES
      end
    end

    if File.exist?(output_file.path)
      begin
        output_file.close if output_file.closed?
        output_file.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "#run" do
    context "exporting to JSON" do
      let(:output_json) { Tempfile.new(["export_output", ".json"]) }
      let(:options) { { format: "json", output: output_json.path } }

      after do
        output_json.close! if File.exist?(output_json.path)
      end

      it "exports to JSON format" do
        expect { command.run(test_lur.path) }.to output(/Exported to/).to_stdout
        expect(File.exist?(output_json.path)).to be true
      end
    end

    context "error handling" do
      let(:options) { { format: "csv", output: output_file.path } }

      it "exports successfully" do
        expect { command.run(test_lur.path) }.to raise_error(/Unknown format/)
      end
    end
  end
end