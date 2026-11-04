require "spec_helper"

RSpec.describe "Expressir" do
  describe "version" do
    it "has a version number" do |example|
      # rubocop:disable all
      GC.stress = ENV["GC_STRESS"] == "true"
      puts "Running tests in GC stress mode. It may take a couple of hours ..." if GC.stress

      print "\n[#{example.description}] "
      # rubocop:enable all

      expect(Expressir::Version::VERSION).not_to be_nil
    end

    it "displays the current version" do |example|
      # rubocop:disable all
      print "\n[#{example.description}] "
      # rubocop:enable all

      command = %w(version)
      output = capture_stdout { Expressir::Cli.start(command) }
      expect(output).to include(Expressir::Version::VERSION)
    end
  end
end
