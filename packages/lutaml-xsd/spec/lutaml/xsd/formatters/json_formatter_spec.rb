# frozen_string_literal: true

require "spec_helper"
require "json"
require_relative "../../../../lib/lutaml/xsd/formatters/json_formatter"

RSpec.describe Lutaml::Xsd::Formatters::JsonFormatter do
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

      it "formats results as valid JSON" do
        output = formatter.format(results)
        expect { JSON.parse(output) }.not_to raise_error
      end

      it "includes summary section with correct counts" do
        output = JSON.parse(formatter.format(results))
        expect(output["summary"]).to eq({
                                          "total" => 2,
                                          "valid" => 2,
                                          "invalid" => 0,
                                        })
      end

      it "includes results array with file information" do
        output = JSON.parse(formatter.format(results))
        expect(output["results"]).to be_an(Array)
        expect(output["results"].size).to eq(2)
        expect(output["results"][0]).to include(
          "file" => "schema1.xsd",
          "valid" => true,
        )
      end

      it "does not include error or detected_version for valid files without version info" do
        output = JSON.parse(formatter.format(results))
        expect(output["results"][0]).not_to have_key("error")
        expect(output["results"][0]).not_to have_key("detected_version")
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

      it "includes error messages in results" do
        output = JSON.parse(formatter.format(results))
        expect(output["results"][0]).to include(
          "file" => "invalid1.xsd",
          "valid" => false,
          "error" => "Not a valid XSD schema",
        )
        expect(output["results"][1]).to include(
          "error" => "Invalid XML syntax",
        )
      end

      it "has correct summary counts" do
        output = JSON.parse(formatter.format(results))
        expect(output["summary"]).to eq({
                                          "total" => 2,
                                          "valid" => 0,
                                          "invalid" => 2,
                                        })
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

      it "correctly formats both valid and invalid files" do
        output = JSON.parse(formatter.format(results))
        expect(output["results"][0]).to include("valid" => true)
        expect(output["results"][1]).to include(
          "valid" => false,
          "error" => "File not found",
        )
        expect(output["results"][2]).to include("valid" => true)
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

      it "includes detected_version in results" do
        output = JSON.parse(formatter.format(results))
        expect(output["results"][0]).to include(
          "file" => "schema1.xsd",
          "valid" => true,
          "detected_version" => "1.0",
        )
        expect(output["results"][1]).to include(
          "detected_version" => "1.1",
        )
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

      it "formats empty results as valid JSON" do
        output = JSON.parse(formatter.format(results))
        expect(output["summary"]).to eq({
                                          "total" => 0,
                                          "valid" => 0,
                                          "invalid" => 0,
                                        })
        expect(output["results"]).to eq([])
      end
    end

    context "with special characters in filenames and errors" do
      let(:results) do
        {
          total: 1,
          valid: false,
          invalid: 1,
          files: [
            { file: "path/to/my schema (v1.0).xsd", valid: false,
              error: "Error with \"quotes\" and special chars" },
          ],
          failed_files: ["path/to/my schema (v1.0).xsd"],
        }
      end

      it "properly escapes special characters in JSON" do
        output = formatter.format(results)
        expect { JSON.parse(output) }.not_to raise_error
        parsed = JSON.parse(output)
        expect(parsed["results"][0]["file"]).to eq("path/to/my schema (v1.0).xsd")
        expect(parsed["results"][0]["error"]).to eq("Error with \"quotes\" and special chars")
      end
    end

    context "output format" do
      let(:results) do
        {
          total: 1,
          valid: 1,
          invalid: 0,
          files: [{ file: "test.xsd", valid: true }],
          failed_files: [],
        }
      end

      it "uses pretty printing for human readability" do
        output = formatter.format(results)
        expect(output).to include("\n")
        expect(output).to match(/\s{2}"summary"/)
      end
    end
  end
end
