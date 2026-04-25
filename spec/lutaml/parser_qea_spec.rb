# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/lutaml/parser"
require "tempfile"

RSpec.describe Lutaml::Parser, "#parse with QEA files" do
  let(:qea_file_path) do
    File.expand_path("../../examples/qea/test.qea", __dir__)
  end

  describe ".parse" do
    context "with QEA file" do
      it "detects QEA file type from extension", :aggregate_failures do
        skip "QEA test file not available" unless File.exist?(qea_file_path)

        file = File.new(qea_file_path)
        result = described_class.parse([file])

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first).to be_a(Lutaml::Uml::Document)
      end

      it "returns array with single document for consistency with XMI",
         :aggregate_failures do
        skip "QEA test file not available" unless File.exist?(qea_file_path)

        file = File.new(qea_file_path)
        result = described_class.parse([file])

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
      end

      it "parses QEA file and creates valid document", :aggregate_failures do
        skip "QEA test file not available" unless File.exist?(qea_file_path)

        file = File.new(qea_file_path)
        documents = described_class.parse([file])
        document = documents.first

        # Verify document structure
        expect(document).to respond_to(:packages)
        expect(document).to respond_to(:classes)
        expect(document).to respond_to(:associations)
      end

      it "loads QEA module when parsing QEA file" do
        skip "QEA test file not available" unless File.exist?(qea_file_path)

        file = File.new(qea_file_path)

        # Lutaml::Qea should be loaded after parsing
        described_class.parse([file])

        expect(defined?(Lutaml::Qea)).to be_truthy
      end
    end

    context "with explicit type override" do
      it "can force QEA parsing with type parameter", :aggregate_failures do
        skip "QEA test file not available" unless File.exist?(qea_file_path)

        file = File.new(qea_file_path)
        result = described_class.parse([file], "qea")

        expect(result).to be_an(Array)
        expect(result.first).to be_a(Lutaml::Uml::Document)
      end
    end

    context "error handling" do
      after do
        tempfile.unlink if defined?(tempfile) && File.exist?(tempfile.path)
      end

      it "raises error for non-existent QEA file" do
        file = double("file", path: "nonexistent.qea")
        allow(File).to receive(:exist?).and_return(false)

        expect do
          described_class.parse([file])
        end.to raise_error(StandardError)
      end

      it "handles invalid QEA file gracefully" do
        # Create temp file with invalid content
        tempfile = Tempfile.new(["invalid", ".qea"])
        tempfile.write("not a valid qea file")
        tempfile.close

        expect do
          described_class.parse([tempfile])
        end.to raise_error(SQLite3::Exception)
      end
    end
  end

  describe "integration with UmlRepository" do
    it "parsed document works with UmlRepository", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      file = File.new(qea_file_path)
      documents = described_class.parse([file])
      document = documents.first

      # Should be able to create repository from parsed document
      repo = Lutaml::UmlRepository::Repository.new(document: document)

      expect(repo).to be_a(Lutaml::UmlRepository::Repository)
      expect(repo.statistics).to be_a(Hash)
      expect(repo.statistics).to have_key(:total_packages)
      expect(repo.statistics).to have_key(:total_classes)
    end
  end
end
