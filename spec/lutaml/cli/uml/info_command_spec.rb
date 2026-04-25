# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/info_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
RSpec.describe Lutaml::Cli::Uml::InfoCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "info_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path, name: "InfoTest", version: "1.5")
    path
  end
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "#run" do
    context "with text format" do
      let(:options) { { format: "text" } }

      it "displays package information" do
        expect do
          command.run(test_lur)
        end.to output(/Package Information/).to_stdout
      end

      it "shows package name and version", :aggregate_failures do
        expect do
          command.run(test_lur)
        end.to output(/Name:.*InfoTest/).to_stdout
        expect do
          command.run(test_lur)
        end.to output(/Version:.*1.5/).to_stdout
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
        expect do
          command.run("nonexistent.lur")
        end.to raise_error(/Package file not found/)
      end
    end
  end
end
