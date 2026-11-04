# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "zip"
require_relative "../../../../lib/lutaml/xsd/commands/tree_command"

RSpec.describe Lutaml::Xsd::Commands::TreeCommand do
  let(:test_package_path) { create_test_package }

  # Create a minimal test package for testing
  def create_test_package
    temp_file = Tempfile.new(["test_package", ".lxr"])
    temp_file.close

    Zip::File.open(temp_file.path, create: true) do |zipfile|
      # Add metadata
      zipfile.get_output_stream("metadata.yaml") do |f|
        f.write({
          "files" => ["test.xsd"],
          "namespace_mappings" => [],
          "created_at" => Time.now.iso8601,
          "lutaml_xsd_version" => "0.1.0",
        }.to_yaml)
      end

      # Add XSD files
      zipfile.get_output_stream("schemas/test.xsd") do |f|
        f.write(<<~XSD)
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="test" type="xs:string"/>
          </xs:schema>
        XSD
      end

      # Add serialized data
      zipfile.get_output_stream("schemas_data/test.marshal") do |f|
        f.write(Marshal.dump({ test: "data" }))
      end

      # Add indexes
      zipfile.get_output_stream("type_index.marshal") do |f|
        f.write(Marshal.dump({}))
      end

      # Add mappings
      zipfile.get_output_stream("namespace_mappings.yaml") do |f|
        f.write([].to_yaml)
      end
    end

    temp_file.path
  end

  after do
    FileUtils.rm_f(test_package_path)
  end

  describe "#initialize" do
    it "initializes with package path and options" do
      command = described_class.new(test_package_path, {})
      expect(command.package_path).to eq(test_package_path)
      expect(command.options).to be_a(Hash)
    end

    it "accepts show_sizes option" do
      command = described_class.new(test_package_path, show_sizes: true)
      expect(command.options[:show_sizes]).to be true
    end

    it "accepts no_color option" do
      command = described_class.new(test_package_path, no_color: true)
      expect(command.options[:no_color]).to be true
    end

    it "accepts format option" do
      command = described_class.new(test_package_path, format: "flat")
      expect(command.options[:format]).to eq("flat")
    end
  end

  describe "#run" do
    it "executes successfully with valid package" do
      command = described_class.new(test_package_path, {})
      expect { command.run }.not_to raise_error
    end

    it "outputs tree structure" do
      command = described_class.new(test_package_path, {})
      expect { command.run }.to output(/metadata\.yaml/).to_stdout
    end

    it "includes package name in output" do
      command = described_class.new(test_package_path, {})
      package_name = File.basename(test_package_path)
      expect do
        command.run
      end.to output(/#{Regexp.escape(package_name)}/).to_stdout
    end

    it "includes summary in output" do
      command = described_class.new(test_package_path, {})
      expect { command.run }.to output(/Summary:/).to_stdout
    end

    context "with show_sizes option" do
      it "displays file sizes" do
        command = described_class.new(test_package_path, show_sizes: true)
        # Should output size indicators like KB or B
        expect { command.run }.to output(/\d+\.?\d*\s+(B|KB|MB)/).to_stdout
      end
    end

    context "with no_color option" do
      it "produces plain text output" do
        command = described_class.new(test_package_path, no_color: true)
        output = nil
        expect do
          command.run
        end.to output { |out| output = out }.to_stdout

        # Should not contain ANSI color codes
        expect(output).not_to match(/\e\[\d+m/)
      end
    end

    context "with tree format" do
      it "displays tree structure" do
        command = described_class.new(test_package_path, format: "tree")
        # Tree should contain tree characters
        expect { command.run }.to output(/[├└│]/).to_stdout
      end
    end

    context "with flat format" do
      it "displays flat list" do
        command = described_class.new(test_package_path, format: "flat")
        # Flat list should include paths
        expect { command.run }.to output(%r{schemas/}).to_stdout
      end
    end

    context "with verbose option" do
      it "outputs verbose messages" do
        command = described_class.new(test_package_path, verbose: true)
        expect { command.run }.to output(/Loading package/).to_stdout
      end
    end
  end

  describe "error handling" do
    it "raises error for non-existent package" do
      command = described_class.new("/nonexistent/package.lxr", {})
      expect do
        command.run
      end.to raise_error(Lutaml::Xsd::Error, /Package file not found/)
    end

    it "outputs error message for non-existent package" do
      command = described_class.new("/nonexistent/package.lxr", {})
      expect do
        command.run
      rescue Lutaml::Xsd::Error
        # Catch error to allow error output verification
      end.to output(/Package file not found/).to_stderr
    end

    it "handles invalid ZIP file gracefully" do
      invalid_file = Tempfile.new(["invalid", ".lxr"])
      invalid_file.write("not a zip file")
      invalid_file.close

      command = described_class.new(invalid_file.path, {})
      expect do
        command.run
      end.to raise_error(Lutaml::Xsd::Error, /Failed to read package/)

      invalid_file.unlink
    end

    it "outputs error message for invalid ZIP" do
      invalid_file = Tempfile.new(["invalid", ".lxr"])
      invalid_file.write("not a zip file")
      invalid_file.close

      command = described_class.new(invalid_file.path, {})
      expect do
        command.run
      rescue Lutaml::Xsd::Error
        # Catch error to allow error output verification
      end.to output(/Failed to read package/).to_stderr

      invalid_file.unlink
    end
  end

  describe "integration with PackageTreeFormatter" do
    it "creates formatter with correct options" do
      command = described_class.new(
        test_package_path,
        show_sizes: true,
        no_color: true,
        format: "flat",
      )

      allow(Lutaml::Xsd::PackageTreeFormatter).to receive(:new).and_call_original

      command.run

      expect(Lutaml::Xsd::PackageTreeFormatter).to have_received(:new).with(
        test_package_path,
        hash_including(
          show_sizes: true,
          no_color: true,
          format: :flat,
        ),
      )
    end

    it "calls format method on formatter" do
      command = described_class.new(test_package_path, {})
      formatter = instance_double(Lutaml::Xsd::PackageTreeFormatter)
      allow(Lutaml::Xsd::PackageTreeFormatter).to receive(:new).and_return(formatter)
      allow(formatter).to receive(:format).and_return("formatted output")

      expect { command.run }.to output("formatted output\n").to_stdout
      expect(formatter).to have_received(:format)
    end
  end
end
