# frozen_string_literal: true

require "spec_helper"
require "lutaml/cli/uml_commands"
require "lutaml/uml_repository/repository"
require "json"
require "yaml"
require "csv"
require "tempfile"

RSpec.describe "Stats and Export Commands (via UmlCommands)" do
  let(:test_lur) { File.join(__dir__, "../../../plateau_all_packages.lur") }
  let(:output_dir) { Dir.mktmpdir }

  before do
    skip "Test LUR file not available" unless File.exist?(test_lur)
  end

  after do
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  describe "stats command" do
    it "shows repository statistics in text format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur])
      }.to output(/Packages:/).to_stdout
       .and output(/Classes:/).to_stdout
    end

    it "shows repository statistics in JSON format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur, "--format", "json"])
      }.to output(/{/).to_stdout
       .and output(/"total_packages"/).to_stdout
    end

    it "shows repository statistics in YAML format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur, "--format", "yaml"])
      }.to output(/total_packages:/).to_stdout
       .and output(/total_classes:/).to_stdout
    end

    it "shows detailed statistics" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur, "--detailed"])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "export command" do
    it "exports to CSV format" do
      output_file = File.join(output_dir, "export.csv")

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "csv",
                                      "-o", output_file])
      }.to output(/Exported to/).to_stdout
      expect(File.exist?(output_file)).to be true

      # Verify CSV structure
      csv_content = File.read(output_file)
      expect(csv_content.lines.size).to be > 1  # Should have header + data rows
    end

    it "exports to JSON format" do
      output_file = File.join(output_dir, "export.json")

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "json",
                                      "-o", output_file])
      }.to output(/Exported to/).to_stdout
      expect(File.exist?(output_file)).to be true
      expect { JSON.parse(File.read(output_file)) }.not_to raise_error
    end

    it "exports to Markdown format" do
      output_file = File.join(output_dir, "export")

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "markdown",
                                      "-o", output_file])
      }.to output(/Exported to/).to_stdout
    end

    it "exports with package filter" do
      output_file = File.join(output_dir, "filtered.json")

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "json",
                                      "-o", output_file,
                                      "--package", "ModelRoot"])
      }.to output(/Exported to/).to_stdout
      expect(File.exist?(output_file)).to be true
    end

    it "exports recursively by default" do
      output_file = File.join(output_dir, "recursive.json")

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "json",
                                      "-o", output_file,
                                      "--recursive"])
      }.to output(/Exported to/).to_stdout
      expect(File.exist?(output_file)).to be true
    end
  end

  describe "tree command" do
    it "shows package tree structure" do
      expect {
        Lutaml::Cli::UmlCommands.start(["tree", test_lur])
      }.not_to output(/ERROR/).to_stdout
    end

    it "shows tree with class counts" do
      expect {
        Lutaml::Cli::UmlCommands.start(["tree", test_lur, "--show-counts"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "shows tree up to specified depth" do
      expect {
        Lutaml::Cli::UmlCommands.start(["tree", test_lur, "--depth", "2"])
      }.not_to output(/ERROR/).to_stdout
    end

    it "outputs tree in JSON format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["tree", test_lur, "--format", "json"])
      }.to output(/{/).to_stdout
    end

    it "outputs tree in YAML format" do
      expect {
        Lutaml::Cli::UmlCommands.start(["tree", test_lur, "--format", "yaml"])
      }.not_to output(/ERROR/).to_stdout
    end
  end

  describe "error handling" do
    it "handles missing LUR file" do
      expect {
        Lutaml::Cli::UmlCommands.start(["stats", "nonexistent.lur"])
      }.to output(/Package file not found|Failed to load/).to_stdout
    end

    it "handles invalid output directory" do
      invalid_path = "/invalid/path/output.json"

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "json",
                                      "-o", invalid_path])
      }.to output(/Failed to export|Export failed/).to_stdout
    end

    it "handles unsupported export format" do
      output_file = File.join(output_dir, "export.invalid")

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "invalid",
                                      "-o", output_file])
      }.to output(/Unknown format/).to_stdout
    end
  end

  describe "performance with large files" do
    it "completes stats command within reasonable time" do
      start_time = Time.now

      expect {
        Lutaml::Cli::UmlCommands.start(["stats", test_lur])
      }.not_to raise_error

      duration = Time.now - start_time
      expect(duration).to be < 10.0  # Should complete within 10 seconds
    end

    it "completes export command within reasonable time" do
      output_file = File.join(output_dir, "performance_test.json")
      start_time = Time.now

      expect {
        Lutaml::Cli::UmlCommands.start(["export", test_lur,
                                      "--format", "json",
                                      "-o", output_file])
      }.not_to raise_error

      duration = Time.now - start_time
      expect(duration).to be < 15.0  # Should complete within 15 seconds
      expect(File.exist?(output_file)).to be true
    end
  end
end