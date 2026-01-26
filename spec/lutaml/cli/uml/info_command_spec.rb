# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/info_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::InfoCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["info_test", ".lur"])
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur.path, name: "InfoTest", version: "1.5")
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    test_lur.close! if File.exist?(test_lur.path)
  end

  describe "#run" do
    context "with text format" do
      let(:options) { { format: "text" } }

      it "displays package information" do
        expect do
          command.run(test_lur.path)
        end.to output(/Package Information/).to_stdout
      end

      it "shows package name and version" do
        expect do
          command.run(test_lur.path)
        end.to output(/Name:.*InfoTest/).to_stdout
        expect do
          command.run(test_lur.path)
        end.to output(/Version:.*1.5/).to_stdout
      end

      it "shows package contents" do
        expect { command.run(test_lur.path) }.to output(/Contents:/).to_stdout
      end
    end

    context "with JSON format" do
      let(:options) { { format: "json" } }

      it "outputs valid JSON" do
        expect { command.run(test_lur.path) }.to output(/"name"/).to_stdout
      end
    end

    context "with YAML format" do
      let(:options) { { format: "yaml" } }

      it "outputs YAML format" do
        expect { command.run(test_lur.path) }.to output(/name:/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { {} }

      it "handles missing LUR file" do
        expect do
          command.run("nonexistent.lur")
        end.to raise_error(/Package file not found/)
      end
    end
  end
end