# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/docs_command"
require_relative "../../../../lib/lutaml/uml_repository"
require "tempfile"
require "fileutils"

RSpec.describe Lutaml::Cli::Uml::DocsCommand do
  let(:test_xmi) { File.join(__dir__, "../../../fixtures/plateau_all_packages_export.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["docs_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:output_dir) { Dir.mktmpdir("docs_output") }
  let(:command) { described_class.new(options) }

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  describe "#run" do
    context "generating documentation" do
      let(:options) { { output: output_dir, title: "Test Docs" } }

      it "generates documentation site" do
        expect { command.run(test_lur) }.to output(/Documentation generated/).to_stdout
      end

      it "shows how to view the documentation" do
        expect { command.run(test_lur) }.to output(/index\.html/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { { output: output_dir } }

      it "handles missing LUR file" do
        expect {
          expect { command.run("nonexistent.lur") }.to raise_error(SystemExit)
        }.to output(/Package file not found/).to_stdout
      end
    end
  end
end