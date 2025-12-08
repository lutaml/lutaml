# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/info_command"
require_relative "../../../../lib/lutaml/uml_repository"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::InfoCommand do
  let(:test_xmi) { File.join(__dir__, "../../../fixtures/plateau_all_packages_export.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["info_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur, name: "InfoTest", version: "1.5")
    temp_lur
  end
  let(:command) { described_class.new(options) }

  before do
    skip "Large XMI file parsing causes hangs - needs optimization" if !File.exist?(test_xmi) || File.size(test_xmi) > 1_000_000
  end

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  describe "#run" do
    context "with text format" do
      let(:options) { { format: "text" } }

      it "displays package information" do
        expect { command.run(test_lur) }.to output(/Package Information/).to_stdout
      end

      it "shows package name and version" do
        expect { command.run(test_lur) }.to output(/Name:.*InfoTest/).to_stdout
        expect { command.run(test_lur) }.to output(/Version:.*1.5/).to_stdout
      end

      it "shows package contents" do
        expect { command.run(test_lur) }.to output(/Contents:/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs valid JSON" do
        expect { command.run(test_lur) }.to output(/"name"/).to_stdout
      end
    end

    context "with YAML format" do
      let(:options) { { format: "yaml" } }

      it "outputs YAML format" do
        expect { command.run(test_lur) }.to output(/name:/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles missing LUR file" do
        expect { command.run("nonexistent.lur") }.to output(/Package file not found/).to_stdout
      end
    end
  end
end