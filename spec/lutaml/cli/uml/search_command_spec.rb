# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/search_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::SearchCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["search_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  describe "#run" do
    context "basic search" do
      let(:options) { { format: "table", type: ["class"], in: ["name"] } }

      it "performs search" do
        expect { command.run(test_lur, "Building") }.not_to output(/ERROR/).to_stdout
      end

      it "shows results or no results message" do
        expect {
          capture(:stdout) { command.run(test_lur, "NonExistent12345") }
        }.not_to raise_error
      end
    end

    context "with regex" do
      let(:options) { { format: "table", type: ["class"], in: ["name"] } }

      it "treats query as regex" do
        expect { command.run(test_lur, "^Building") }.not_to output(/ERROR/).to_stdout
      end
    end

    context "with different formats" do
      let(:options) { { format: "json", type: ["class"], in: ["name"] } }

      it "outputs JSON format" do
        expect { command.run(test_lur, "test") }.to output(/{|w+/).to_stdout
      end
    end
  end

  def capture(stream)
    old_stream = stream == :stdout ? $stdout : $stderr
    stream_var = stream == :stdout ? :$stdout : :$stderr
    eval("#{stream_var} = StringIO.new")
    yield
    eval("#{stream_var}.string")
  ensure
    eval("#{stream_var} = old_stream")
  end
end