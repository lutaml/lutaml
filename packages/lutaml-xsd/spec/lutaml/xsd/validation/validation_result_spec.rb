# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/validation_result"
require "lutaml/xsd/validation/validation_error"

RSpec.describe Lutaml::Xsd::Validation::ValidationResult do
  let(:error1) do
    Lutaml::Xsd::Validation::ValidationError.new(
      code: "type_mismatch",
      message: "Invalid type",
      severity: :error,
      location: "/root/element[1]",
    )
  end

  let(:error2) do
    Lutaml::Xsd::Validation::ValidationError.new(
      code: "missing_attribute",
      message: "Required attribute missing",
      severity: :error,
      location: "/root/element[2]",
    )
  end

  let(:warning1) do
    Lutaml::Xsd::Validation::ValidationError.new(
      code: "deprecated_usage",
      message: "Using deprecated element",
      severity: :warning,
      location: "/root",
    )
  end

  describe "#initialize" do
    it "initializes with valid flag" do
      result = described_class.new(valid: true)
      expect(result.valid?).to be true
    end

    it "initializes with errors" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result.errors).to contain_exactly(error1)
    end

    it "initializes with warnings" do
      result = described_class.new(valid: true, warnings: [warning1])
      expect(result.warnings).to contain_exactly(warning1)
    end

    it "initializes with empty collections by default" do
      result = described_class.new(valid: true)
      expect(result.errors).to be_empty
      expect(result.warnings).to be_empty
    end
  end

  describe "#valid?" do
    it "returns true when no errors" do
      result = described_class.new(valid: true)
      expect(result).to be_valid
    end

    it "returns false when errors present" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result).not_to be_valid
    end

    it "returns false even if valid flag is true but errors exist" do
      result = described_class.new(valid: true, errors: [error1])
      expect(result).not_to be_valid
    end
  end

  describe "#invalid?" do
    it "returns false when valid" do
      result = described_class.new(valid: true)
      expect(result).not_to be_invalid
    end

    it "returns true when invalid" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result).to be_invalid
    end
  end

  describe "#error_count" do
    it "returns 0 when no errors" do
      result = described_class.new(valid: true)
      expect(result.error_count).to eq(0)
    end

    it "returns correct count with errors" do
      result = described_class.new(valid: false, errors: [error1, error2])
      expect(result.error_count).to eq(2)
    end
  end

  describe "#warning_count" do
    it "returns 0 when no warnings" do
      result = described_class.new(valid: true)
      expect(result.warning_count).to eq(0)
    end

    it "returns correct count with warnings" do
      result = described_class.new(valid: true, warnings: [warning1])
      expect(result.warning_count).to eq(1)
    end
  end

  describe "#total_issues" do
    it "returns sum of errors and warnings" do
      result = described_class.new(
        valid: false,
        errors: [error1, error2],
        warnings: [warning1],
      )
      expect(result.total_issues).to eq(3)
    end
  end

  describe "#errors?" do
    it "returns true when errors present" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result.errors?).to be true
    end

    it "returns false when no errors" do
      result = described_class.new(valid: true)
      expect(result.errors?).to be false
    end
  end

  describe "#warnings?" do
    it "returns true when warnings present" do
      result = described_class.new(valid: true, warnings: [warning1])
      expect(result.warnings?).to be true
    end

    it "returns false when no warnings" do
      result = described_class.new(valid: true)
      expect(result.warnings?).to be false
    end
  end

  describe "#errors_by_severity" do
    let(:result) do
      described_class.new(
        valid: false,
        errors: [error1, error2],
        warnings: [warning1],
      )
    end

    it "returns errors for error severity" do
      errors = result.errors_by_severity(:error)
      expect(errors).to contain_exactly(error1, error2)
    end

    it "returns warnings for warning severity" do
      warnings = result.errors_by_severity(:warning)
      expect(warnings).to contain_exactly(warning1)
    end

    it "returns empty array for unused severity" do
      info = result.errors_by_severity(:info)
      expect(info).to be_empty
    end
  end

  describe "#all_issues" do
    it "returns combined errors and warnings" do
      result = described_class.new(
        valid: false,
        errors: [error1],
        warnings: [warning1],
      )
      expect(result.all_issues).to contain_exactly(error1, warning1)
    end
  end

  describe "#errors_by_code" do
    it "groups errors by code" do
      result = described_class.new(
        valid: false,
        errors: [error1, error2],
      )
      grouped = result.errors_by_code
      expect(grouped["type_mismatch"]).to contain_exactly(error1)
      expect(grouped["missing_attribute"]).to contain_exactly(error2)
    end
  end

  describe "#errors_at" do
    it "returns errors at specific location" do
      result = described_class.new(
        valid: false,
        errors: [error1, error2],
      )
      errors = result.errors_at("/root/element[1]")
      expect(errors).to contain_exactly(error1)
    end

    it "returns empty array for non-existent location" do
      result = described_class.new(
        valid: false,
        errors: [error1],
      )
      errors = result.errors_at("/nonexistent")
      expect(errors).to be_empty
    end
  end

  describe "#summary" do
    it "returns success message for valid result" do
      result = described_class.new(valid: true)
      expect(result.summary).to include("✓")
      expect(result.summary).to include("successful")
    end

    it "returns failure message for invalid result" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result.summary).to include("✗")
      expect(result.summary).to include("failed")
      expect(result.summary).to include("1 errors")
    end

    it "includes warning count" do
      result = described_class.new(valid: true, warnings: [warning1])
      expect(result.summary).to include("1 warnings")
    end
  end

  describe "#to_h" do
    it "converts to hash representation" do
      result = described_class.new(
        valid: false,
        errors: [error1],
        warnings: [warning1],
      )
      hash = result.to_h
      expect(hash[:valid]).to be false
      expect(hash[:error_count]).to eq(1)
      expect(hash[:warning_count]).to eq(1)
      expect(hash[:errors]).to be_an(Array)
      expect(hash[:warnings]).to be_an(Array)
    end
  end

  describe "#to_json" do
    it "converts to JSON string" do
      result = described_class.new(valid: true)
      json = result.to_json
      expect(json).to be_a(String)
      expect(JSON.parse(json)).to be_a(Hash)
    end
  end

  describe "#detailed_report" do
    it "generates detailed report with errors" do
      result = described_class.new(valid: false, errors: [error1])
      report = result.detailed_report
      expect(report).to include("Errors:")
      expect(report).to include(error1.message)
    end

    it "includes warnings when requested" do
      result = described_class.new(
        valid: false,
        errors: [error1],
        warnings: [warning1],
      )
      report = result.detailed_report(include_warnings: true)
      expect(report).to include("Warnings:")
      expect(report).to include(warning1.message)
    end

    it "excludes warnings when not requested" do
      result = described_class.new(
        valid: false,
        errors: [error1],
        warnings: [warning1],
      )
      report = result.detailed_report(include_warnings: false)
      expect(report).not_to include("Warnings:")
    end
  end

  describe "#has_error_code?" do
    it "returns true when error code exists" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result.has_error_code?("type_mismatch")).to be true
    end

    it "returns false when error code doesn't exist" do
      result = described_class.new(valid: false, errors: [error1])
      expect(result.has_error_code?("unknown_code")).to be false
    end
  end

  describe "#first_error" do
    it "returns first error" do
      result = described_class.new(valid: false, errors: [error1, error2])
      expect(result.first_error).to eq(error1)
    end

    it "returns nil when no errors" do
      result = described_class.new(valid: true)
      expect(result.first_error).to be_nil
    end
  end

  describe "#first_warning" do
    it "returns first warning" do
      result = described_class.new(valid: true, warnings: [warning1])
      expect(result.first_warning).to eq(warning1)
    end

    it "returns nil when no warnings" do
      result = described_class.new(valid: true)
      expect(result.first_warning).to be_nil
    end
  end
end
