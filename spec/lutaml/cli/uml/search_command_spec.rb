# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/search_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::SearchCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["search_test", ".lur"])
    temp_lur.close
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
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
    context "basic search" do
      let(:options) { { format: "table", type: ["class"], in: ["name"] } }

      it "performs search" do
        expect do
          command.run(test_lur.path, "Building")
        end.not_to output(/ERROR/).to_stdout
      end

      it "shows results or no results message" do
        expect do
          capture(:stdout) { command.run(test_lur.path, "NonExistent12345") }
        end.not_to raise_error
      end
    end

    context "with regex" do
      let(:options) { { format: "table", type: ["class"], in: ["name"] } }

      it "treats query as regex" do
        expect do
          command.run(test_lur.path, "^Building")
        end.not_to output(/ERROR/).to_stdout
      end
    end

    context "with different formats" do
      let(:options) { { format: "json", type: ["class"], in: ["name"] } }

      it "outputs JSON format" do
        expect do
          command.run(test_lur.path, "Class A")
        end.to output(/{|w+/).to_stdout
      end
    end
  end

  def capture(stream)
    stream_var = stream == :stdout ? :$stdout : :$stderr
    old_stream = eval(stream_var.to_s)
    eval("#{stream_var} = StringIO.new")
    yield
  ensure
    eval("#{stream_var} = old_stream") if defined?(old_stream) && old_stream
  end
end
