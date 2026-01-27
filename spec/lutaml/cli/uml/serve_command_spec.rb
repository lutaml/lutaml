# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/serve_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"
require "tempfile"

RSpec.describe Lutaml::Cli::Uml::ServeCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    temp_lur = Tempfile.new(["serve_test", ".lur"]).path
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(temp_lur)
    temp_lur
  end
  let(:command) { described_class.new(options) }

  before do
    if !File.exist?(test_xmi) || File.size(test_xmi) > 1_000_000
      skip "Large XMI file parsing causes hangs - needs optimization"
    end
  end

  after do
    File.unlink(test_lur) if File.exist?(test_lur)
  end

  describe "#run" do
    let(:options) { { port: 3000, host: "localhost" } }

    it "handles missing LUR file" do
      expect do
        command.run("nonexistent.lur")
      end.to raise_error(/Package file not found/)
    end

    # Note: Actual server testing skipped as it would start a blocking process
  end
end
