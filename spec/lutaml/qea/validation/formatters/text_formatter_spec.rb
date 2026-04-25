# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../../lib/lutaml/qea/validation/formatters/" \
                 "text_formatter"
require_relative "../../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../../lib/lutaml/qea/validation/validation_message"

RSpec.describe Lutaml::Qea::Validation::Formatters::TextFormatter do
  let(:result) { Lutaml::Qea::Validation::ValidationResult.new }

  describe "#initialize" do
    it "creates formatter with result", :aggregate_failures do
      formatter = described_class.new(result: result)

      expect(formatter.result).to eq(result)
      expect(formatter.options[:color]).to be true
      expect(formatter.options[:verbose]).to be false
    end

    it "accepts color option" do
      formatter = described_class.new(result: result, color: false)

      expect(formatter.options[:color]).to be false
    end

    it "accepts verbose option" do
      formatter = described_class.new(result: result, verbose: true)

      expect(formatter.options[:verbose]).to be true
    end

    it "accepts limit option" do
      formatter = described_class.new(result: result, limit: 10)

      expect(formatter.options[:limit]).to eq(10)
    end
  end

  describe "#format" do
    context "with no messages" do
      it "shows valid status", :aggregate_failures do
        formatter = described_class.new(result: result, color: false)
        output = formatter.format

        expect(output).to include("VALIDATION REPORT")
        expect(output).to include("✓ VALID")
        expect(output).to include("Errors:   0")
        expect(output).to include("Warnings: 0")
      end
    end

    context "with errors" do
      before do
        result.add_error(
          category: :missing_reference,
          entity_type: :class,
          entity_id: "123",
          entity_name: "TestClass",
          message: "Class not found",
        )
      end

      it "shows error status", :aggregate_failures do
        formatter = described_class.new(result: result, color: false)
        output = formatter.format

        expect(output).to include("✗ INVALID")
        expect(output).to include("Errors:   1")
        expect(output).to include("Warnings: 0")
      end

      it "displays error messages", :aggregate_failures do
        formatter = described_class.new(result: result, color: false)
        output = formatter.format

        expect(output).to include("ERRORS (1):")
        expect(output).to include("Missing Reference")
        expect(output).to include("class:TestClass")
        expect(output).to include("Class not found")
        expect(output).to include("ID: 123")
      end

      it "applies color when enabled" do
        formatter = described_class.new(result: result, color: true)
        output = formatter.format

        # Should contain ANSI color codes
        expect(output).to match(/\e\[\d+m/)
      end

      it "limits messages when specified", :aggregate_failures do
        5.times do |i|
          result.add_error(
            category: :missing_reference,
            entity_type: :class,
            entity_id: i.to_s,
            entity_name: "Class#{i}",
            message: "Error #{i}",
          )
        end

        formatter = described_class.new(result: result, color: false, limit: 3)
        output = formatter.format

        expect(output).to include("Errors:   6")
        expect(output).to include("... and 3 more")
      end
    end

    context "with warnings" do
      before do
        result.add_warning(
          category: :missing_documentation,
          entity_type: :class,
          entity_id: "456",
          entity_name: "UndocumentedClass",
          message: "Class lacks documentation",
        )
      end

      it "shows warning status", :aggregate_failures do
        formatter = described_class.new(result: result, color: false)
        output = formatter.format

        expect(output).to include("⚠ class:UndocumentedClass")
        expect(output).to include("Errors:   0")
        expect(output).to include("Warnings: 1")
      end

      it "displays warning messages", :aggregate_failures do
        formatter = described_class.new(result: result, color: false)
        output = formatter.format

        expect(output).to include("WARNINGS (1):")
        expect(output).to include("Missing Documentation")
        expect(output).to include("Class lacks documentation")
      end
    end

    context "with info messages" do
      before do
        result.add_info(
          category: :usage_tip,
          entity_type: :package,
          entity_id: "789",
          entity_name: "ModelPackage",
          message: "Consider adding more classes",
        )
      end

      it "hides info by default", :aggregate_failures do
        formatter = described_class.new(result: result, color: false,
                                        verbose: false)
        output = formatter.format

        expect(output).not_to include("INFO")
        expect(output).not_to include("Consider adding more classes")
      end

      it "shows info when verbose", :aggregate_failures do
        formatter = described_class.new(result: result, color: false,
                                        verbose: true)
        output = formatter.format

        expect(output).to include("INFO (1):")
        expect(output).to include("Usage Tip")
        expect(output).to include("Consider adding more classes")
      end
    end

    context "with mixed severity messages" do
      before do
        result.add_error(
          category: :missing_reference,
          entity_type: :class,
          entity_id: "1",
          entity_name: "ErrorClass",
          message: "Critical error",
        )
        result.add_warning(
          category: :missing_documentation,
          entity_type: :class,
          entity_id: "2",
          entity_name: "WarningClass",
          message: "Minor warning",
        )
      end

      it "displays all severity levels", :aggregate_failures do
        formatter = described_class.new(result: result, color: false)
        output = formatter.format

        expect(output).to include("ERRORS (1):")
        expect(output).to include("WARNINGS (1):")
        expect(output).to include("Critical error")
        expect(output).to include("Minor warning")
      end
    end
  end
end
