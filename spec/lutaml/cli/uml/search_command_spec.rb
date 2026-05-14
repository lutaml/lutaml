# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli"

require_relative "../../../../lib/lutaml/uml_repository"
RSpec.describe Lutaml::Cli::Uml::SearchCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../spec/fixtures/ea-xmi-2.5.1.xmi") }
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
          command.run(test_lur, "Requirement")
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
          command.run(test_lur, "^Requirement")
        end.not_to output(/ERROR/).to_stdout
      end
    end

    context "with different formats" do
      let(:options) { { format: "json", type: ["class"], in: ["name"] } }

      it "outputs JSON format" do
        expect do
          command.run(test_lur, "Requirement")
        end.to output(/\[/).to_stdout
      end
    end
  end

  def capture(stream)
    stream_var = stream == :stdout ? $stdout : $stderr
    old_stream = stream_var
    case stream
    when :stdout then $stdout = StringIO.new
    when :stderr then $stderr = StringIO.new
    end
    yield
  ensure
    case stream
    when :stdout then $stdout = old_stream
    when :stderr then $stderr = old_stream
    end
  end
end
