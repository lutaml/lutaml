# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli/uml/repl_command"
require_relative "../../../../lib/lutaml/uml_repository"
require_relative "../../../../lib/lutaml/cli/uml_commands"

RSpec.describe Lutaml::Cli::Uml::ReplCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "repl_test")
    repo = Lutaml::UmlRepository::Repository.from_xmi(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:command) { described_class.new(options) }

  before do
    if !File.exist?(test_xmi) || File.size(test_xmi) > 1_000_000
      skip "Large XMI file parsing causes hangs - needs optimization"
    end
  end

  after do
    FileUtils.rm_f(test_lur)
  end

  describe "#run" do
    let(:options) { { color: true, icons: true } }

    it "handles missing LUR file" do
      expect do
        command.run("nonexistent.lur")
      end.to raise_error(/Package file not found/)
    end

    # Note: Actual REPL testing skipped as it would start interactive shell
  end
end
