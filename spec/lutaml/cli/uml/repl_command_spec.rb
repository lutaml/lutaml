# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/repl_command"
require_relative "../../../../lib/lutaml/uml_repository"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::ReplCommand do
  let(:test_xmi) { File.join(__dir__, "../../../fixtures/plateau_all_packages_export.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["repl_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  describe "#run" do
    let(:options) { { color: true, icons: true } }

    it "handles missing LUR file" do
      expect {
        expect { command.run("nonexistent.lur") }.to raise_error(SystemExit)
      }.to output(/Package file not found/).to_stdout
    end

    # Note: Actual REPL testing skipped as it would start interactive shell
  end
end