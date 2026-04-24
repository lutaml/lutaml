# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/export_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
RSpec.describe Lutaml::Cli::Uml::ExportCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "export_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:output_file) { temp_lur_path(prefix: "export_output").sub(/\.lur$/, ".csv") }
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
    FileUtils.rm_f(output_file)
  end

  describe "#run" do
    context "exporting to JSON" do
      let(:output_json) { temp_lur_path(prefix: "export_output").sub(/\.lur$/, ".json") }
      let(:options) { { format: "json", output: output_json } }

      after do
        FileUtils.rm_f(output_json)
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
