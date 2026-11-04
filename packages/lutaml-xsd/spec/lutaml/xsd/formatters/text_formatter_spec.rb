# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/xsd/formatters/text_formatter"

RSpec.describe Lutaml::Xsd::Formatters::TextFormatter do
  describe "#format" do
    let(:formatter) { described_class.new }

    context "with valid files only" do
      let(:results) do
        {
          total: 2,
          valid: 2,
          invalid: 0,
          files: [
            { file: "schema1.xsd", valid: true },
            { file: "schema2.xsd", valid: true },
          ],
          failed_files: [],
        }
      end

      it "formats valid files with checkmarks" do
        output = formatter.format(results)
        expect(output).to include("✓ schema1.xsd")
        expect(output).to include("✓ schema2.xsd")
      end

      it "includes summary section" do
        output = formatter.format(results)
        expect(output).to include("Summary:")
        expect(output).to include("Total: 2")
        expect(output).to include("Valid: 2")
        expect(output).to include("Invalid: 0")
      end
    end

    context "with invalid files only" do
      let(:results) do
        {
          total: 2,
          valid: 0,
          invalid: 2,
          files: [
            { file: "invalid1.xsd", valid: false,
              error: "Not a valid XSD schema" },
            { file: "invalid2.xsd", valid: false, error: "Invalid XML syntax" },
          ],
          failed_files: ["invalid1.xsd", "invalid2.xsd"],
        }
      end

      it "formats invalid files with X marks" do
        output = formatter.format(results)
        expect(output).to include("✗ invalid1.xsd")
        expect(output).to include("✗ invalid2.xsd")
      end

      it "includes error messages" do
        output = formatter.format(results)
        expect(output).to include("Error: Not a valid XSD schema")
        expect(output).to include("Error: Invalid XML syntax")
      end

      it "includes summary with correct counts" do
        output = formatter.format(results)
        expect(output).to include("Total: 2")
        expect(output).to include("Valid: 0")
        expect(output).to include("Invalid: 2")
      end
    end

    context "with mixed valid and invalid files" do
      let(:results) do
        {
          total: 3,
          valid: 2,
          invalid: 1,
          files: [
            { file: "valid1.xsd", valid: true },
            { file: "invalid.xsd", valid: false, error: "File not found" },
            { file: "valid2.xsd", valid: true },
          ],
          failed_files: ["invalid.xsd"],
        }
      end

      it "formats both valid and invalid files correctly" do
        output = formatter.format(results)
        expect(output).to include("✓ valid1.xsd")
        expect(output).to include("✗ invalid.xsd")
        expect(output).to include("✓ valid2.xsd")
        expect(output).to include("Error: File not found")
      end
    end

    context "with detected version information" do
      let(:results) do
        {
          total: 2,
          valid: 2,
          invalid: 0,
          files: [
            { file: "schema1.xsd", valid: true, detected_version: "1.0" },
            { file: "schema2.xsd", valid: true, detected_version: "1.1" },
          ],
          failed_files: [],
        }
      end

      it "includes detected XSD version in output" do
        output = formatter.format(results)
        expect(output).to include("✓ schema1.xsd (XSD 1.0)")
        expect(output).to include("✓ schema2.xsd (XSD 1.1)")
      end
    end

    context "with empty results" do
      let(:results) do
        {
          total: 0,
          valid: 0,
          invalid: 0,
          files: [],
          failed_files: [],
        }
      end

      it "formats empty results with summary only" do
        output = formatter.format(results)
        expect(output).to include("Summary:")
        expect(output).to include("Total: 0")
        expect(output).to include("Valid: 0")
        expect(output).to include("Invalid: 0")
      end
    end

    context "with special characters in filenames" do
      let(:results) do
        {
          total: 1,
          valid: 1,
          invalid: 0,
          files: [
            { file: "path/to/my schema (v1.0).xsd", valid: true },
          ],
          failed_files: [],
        }
      end

      it "handles special characters in filenames" do
        output = formatter.format(results)
        expect(output).to include("✓ path/to/my schema (v1.0).xsd")
      end
    end
  end
end
