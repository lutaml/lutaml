# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/search_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
RSpec.describe Lutaml::Cli::Uml::SearchCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "search_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "#run" do
    context "basic search" do
      let(:options) { { format: "table", type: ["class"], in: ["name"] } }

      it "performs search" do
        expect do
          command.run(test_lur, "Building")
        end.not_to output(/ERROR/).to_stdout
      end

      it "shows results or no results message" do
        expect do
          capture(:stdout) { command.run(test_lur, "NonExistent12345") }
        end.not_to raise_error
      end
    end

    context "with regex" do
      let(:options) { { format: "table", type: ["class"], in: ["name"] } }

      it "treats query as regex" do
        expect do
          command.run(test_lur, "^Building")
        end.not_to output(/ERROR/).to_stdout
      end
    end

    context "with different formats" do
      let(:options) { { format: "json", type: ["class"], in: ["name"] } }

      it "outputs JSON format" do
        expect do
          command.run(test_lur, "Class A")
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
