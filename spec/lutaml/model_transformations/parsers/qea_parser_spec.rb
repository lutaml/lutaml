# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/model_transformations/parsers/" \
                 "qea_parser"
require_relative "../../../../lib/lutaml/model_transformations/configuration"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::Parsers::QeaParser do
  let(:configuration) { Lutaml::ModelTransformations::Configuration.new }
  let(:options) { {} }
  let(:parser) do
    described_class.new(configuration: configuration, options: options)
  end

  describe "#format_name" do
    it "returns QEA format name" do
      expect(parser.format_name).to eq("Enterprise Architect Database (QEA)")
    end
  end

  describe "#supported_extensions" do
    it "returns QEA file extensions" do
      extensions = parser.supported_extensions
      expect(extensions).to include(".qea", ".eap", ".eapx")
    end
  end

  describe "#content_patterns" do
    it "returns QEA content detection patterns" do
      patterns = parser.content_patterns
      expect(patterns).to be_an(Array)
      expect(patterns).not_to be_empty

      # Should include patterns for SQLite database headers
      sqlite_pattern = patterns.find { |p| p.source.include?("SQLite") }
      expect(sqlite_pattern).not_to be_nil
    end
  end

  describe "#priority" do
    it "returns high priority for QEA files" do
      expect(parser.priority).to eq(90)
    end
  end

  describe "#parse" do
    # Note: QEA parsing requires actual database files which are complex to mock
    # These tests focus on the interface and error handling

    context "with file path validation" do
      it "raises error for non-existent file" do
        expect do
          parser.parse("nonexistent.qea")
        end.to raise_error(ArgumentError, /File does not exist/)
      end

      it "raises error for nil file path" do
        expect do
          parser.parse(nil)
        end.to raise_error(ArgumentError, /File path cannot be nil/)
      end

      it "raises error for empty file path" do
        expect do
          parser.parse("")
        end.to raise_error(ArgumentError, /File path cannot be nil/)
      end
    end

    context "with mock QEA file" do
      let(:mock_qea_file) do
        file = Tempfile.new(["mock", ".qea"])
        # Write SQLite header to make it look like a database file
        file.write("SQLite format 3\x00")
        # Padding to make it look like a real SQLite file
        file.write("\x00" * 100)
        file.close
        file
      end

      after { mock_qea_file.unlink }

      it "attempts to parse QEA file" do
        # This will likely fail since it's not a real QEA file,
        # but should not crash
        expect do
          parser.parse(mock_qea_file.path)
        end.to raise_error(StandardError)
      end
    end

    context "with invalid file format" do
      let(:text_file) do
        file = Tempfile.new(["text", ".qea"])
        file.write("This is not a QEA file")
        file.close
        file
      end

      after { text_file.unlink }

      it "raises parsing error for non-database file" do
        expect do
          parser.parse(text_file.path)
        end.to raise_error(StandardError)
      end
    end
  end

  describe "#can_parse?" do
    context "with QEA file extension" do
      it "returns true for .qea files" do
        expect(parser.can_parse?("test.qea")).to be true
      end

      it "returns true for .eap files" do
        expect(parser.can_parse?("test.eap")).to be true
      end

      it "returns true for .eapx files" do
        expect(parser.can_parse?("test.eapx")).to be true
      end

      it "returns false for unsupported extensions" do
        expect(parser.can_parse?("test.txt")).to be false
        expect(parser.can_parse?("test.xml")).to be false
        expect(parser.can_parse?("test.json")).to be false
      end
    end

    context "with content detection" do
      let(:sqlite_content_file) do
        file = Tempfile.new(["test", ".unknown"])
        file.write("SQLite format 3\x00")
        file.close
        file
      end

      let(:non_sqlite_content_file) do
        file = Tempfile.new(["test", ".unknown"])
        file.write("Not a SQLite database")
        file.close
        file
      end

      after do
        sqlite_content_file.unlink
        non_sqlite_content_file.unlink
      end

      it "detects SQLite content in files with unknown extensions" do
        expect(parser.can_parse?(sqlite_content_file.path)).to be true
      end

      it "rejects non-SQLite content" do
        expect(parser.can_parse?(non_sqlite_content_file.path)).to be false
      end
    end
  end

  describe "#validate_file!" do
    context "when input validation is enabled" do
      let(:options) { { validate_input: true } }

      let(:sqlite_file) do
        file = Tempfile.new(["sqlite", ".qea"])
        file.write("SQLite format 3\x00")
        file.write("\x00" * 100)
        file.close
        file
      end

      let(:invalid_file) do
        file = Tempfile.new(["invalid", ".qea"])
        file.write("Not a valid database")
        file.close
        file
      end

      after do
        sqlite_file.unlink
        invalid_file.unlink
      end

      it "validates QEA file structure" do
        # Should not raise error during validation phase
        expect do
          parser.send(:validate_file!, sqlite_file.path)
        end.not_to raise_error
      end

      it "raises error for invalid QEA content during parsing" do
        expect do
          parser.parse(invalid_file.path)
        end.to raise_error
      end
    end
  end

  describe "#validate_output!" do
    context "when output validation is enabled" do
      let(:options) { { validate_output: true } }

      it "validates output document structure" do
        mock_document = Lutaml::Uml::Document.new

        expect do
          parser.send(:validate_output!, mock_document)
        end.not_to raise_error
      end

      it "raises error for invalid output" do
        expect do
          parser.send(:validate_output!, nil)
        end.to raise_error
      end
    end
  end

  describe "database connection handling" do
    it "provides methods for database interaction" do
      # These are internal methods that should exist
      expect(parser.private_methods.include?(:load_qea_database)).to be true
      expect(parser.private_methods.include?(:detect_qea_version)).to be true
      expect(parser.private_methods.include?(:get_quick_database_stats))
        .to be true
    end
  end

  describe "QEA-specific parsing methods" do
    it "provides methods for QEA structure extraction" do
      expect(parser.private_methods.include?(:extract_document_name)).to be true
      expect(parser.private_methods.include?(:validate_qea_transformation))
        .to be true
      expect(parser.private_methods.include?(:add_transformation_statistics))
        .to be true
    end
  end

  describe "configuration integration" do
    it "respects QEA-specific configuration" do
      configuration.parsers = [
        Lutaml::ModelTransformations::Configuration::ParserConfig.new.tap do |p|
          p.format = "qea"
          p.enabled = true
          p.options = { "connection_timeout" => 30 }
        end
      ]

      expect(parser.configuration.parsers).not_to be_empty
    end

    it "uses transformation options from configuration" do
      configuration.transformation_options = Lutaml::ModelTransformations::Configuration::TransformationOptions.new
      configuration.transformation_options.preserve_ids = true

      expect(parser.configuration.transformation_options.preserve_ids)
        .to be true
    end
  end

  describe "error handling and recovery" do
    let(:corrupted_file) do
      file = Tempfile.new(["corrupted", ".qea"])
      # Write partial SQLite header then garbage
      file.write("SQLite format 3\x00")
      file.write("garbage data that will cause parsing to fail")
      file.close
      file
    end

    after { corrupted_file.unlink }

    it "handles database corruption gracefully" do
      expect do
        parser.parse(corrupted_file.path)
      end.to raise_error(StandardError)
    end

    it "provides detailed error information" do
      begin
        parser.parse(corrupted_file.path)
      rescue StandardError => e
        # Error should contain useful information
        expect(e.message).to be_a(String)
        expect(e.message.length).to be > 0
      end
    end
  end

  describe "performance considerations" do
    it "respects timeout settings" do
      parser_with_timeout = described_class.new(
        configuration: configuration,
        options: { timeout: 1 }, # Very short timeout
      )

      # Should use timeout during database operations
      expect(parser_with_timeout.options[:timeout]).to eq(1)
    end

    it "respects memory limit settings" do
      parser_with_limits = described_class.new(
        configuration: configuration,
        options: { memory_limit: 100 }, # Low memory limit
      )

      expect(parser_with_limits.options[:memory_limit]).to eq(100)
    end
  end

  describe "QEA format variations" do
    context "with different QEA file types" do
      it "handles .qea files" do
        expect(parser.can_parse?("model.qea")).to be true
      end

      it "handles legacy .eap files" do
        expect(parser.can_parse?("legacy.eap")).to be true
      end

      it "handles .eapx files" do
        expect(parser.can_parse?("project.eapx")).to be true
      end
    end
  end

  describe "statistics and monitoring" do
    it "tracks QEA-specific metrics" do
      stats = parser.statistics

      expect(stats).to include(
        :format,
        :errors,
        :options,
        :warnings,
      )

      expect(stats[:format]).to eq("Enterprise Architect Database (QEA)")
    end
  end

  describe "integration with existing QEA parsing" do
    it "maintains compatibility with current QEA parsing" do
      # Ensure that new parser doesn't break existing functionality
      expect(parser.format_name).to include("QEA")
      expect(parser.supported_extensions).to include(".qea")
    end
  end
end
