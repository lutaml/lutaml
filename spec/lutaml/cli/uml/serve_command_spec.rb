# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/serve_command"
require_relative "../../../../lib/lutaml/uml_repository"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::ServeCommand do
  let(:test_xmi) { File.join(__dir__, "../../../fixtures/plateau_all_packages_export.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["serve_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  describe "#run" do
    let(:options) { { port: 3000, host: "localhost" } }

    it "handles missing LUR file" do
      expect {
        expect { command.run("nonexistent.lur") }.to raise_error(SystemExit)
      }.to output(/Package file not found/).to_stdout
    end

    # Note: Actual server testing skipped as it would start a blocking process
  end
end