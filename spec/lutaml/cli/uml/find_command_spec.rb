# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/find_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::FindCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["find_test", ".lur"])
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    temp_lur.close
    repo.export_to_package(temp_lur.path)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    if File.exist?(test_lur.path)
      begin
        test_lur.close if !test_lur.closed?
        test_lur.unlink
      rescue Errno::EACCES
      end
    end
  end

  describe "#run" do
    context "finding by stereotype" do
      let(:options) { { stereotype: "interface", format: "text" } }

      it "finds elements by stereotype" do
        expect { command.run(test_lur.path) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "finding by package" do
      let(:options) { { package: "ModelRoot", format: "text" } }

      it "finds elements in package" do
        expect { command.run(test_lur.path) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "finding by pattern" do
      let(:options) { { pattern: "^Building", format: "text" } }

      it "finds elements matching pattern" do
        expect { command.run(test_lur.path) }.not_to output(/ERROR/).to_stdout
      end
    end

    context "error handling" do
      let(:options) { { format: "text" } }

      it "requires at least one filter" do
        expect do
          command.run(test_lur.path)
        end.to raise_error(/Please specify at least one filter/)
      end
    end
  end
end
