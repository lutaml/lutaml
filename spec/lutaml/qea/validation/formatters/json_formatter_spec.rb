# frozen_string_literal: true

require "spec_helper"
require "json"
require_relative "../../../../../lib/lutaml/qea/validation/formatters/json_formatter"
require_relative "../../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../../lib/lutaml/qea/validation/validation_message"

RSpec.describe Lutaml::Qea::Validation::Formatters::JsonFormatter do
  let(:result) { Lutaml::Qea::Validation::ValidationResult.new }

  describe "#initialize" do
    it "creates formatter with result" do
      formatter = described_class.new(result: result)

      expect(formatter.result).to eq(result)
      expect(formatter.options[:pretty]).to be false
    end

    it "accepts pretty option" do
      formatter = described_class.new(result: result, pretty: true)

      expect(formatter.options[:pretty]).to be true
    end
  end

  describe "#format" do
    context "with no messages" do
      it "returns valid JSON" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data).to be_a(Hash)
        expect(data["summary"]["valid"]).to be true
        expect(data["summary"]["total_messages"]).to eq(0)
        expect(data["summary"]["error_count"]).to eq(0)
        expect(data["summary"]["warning_count"]).to eq(0)
        expect(data["summary"]["info_count"]).to eq(0)
      end

      it "includes all required sections" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data).to have_key("summary")
        expect(data).to have_key("messages")
        expect(data).to have_key("by_category")
        expect(data).to have_key("by_severity")
      end
    end

    context "with errors" do
      before do
        result.add_error(
          category: :missing_reference,
          entity_type: :class,
          entity_id: "123",
          entity_name: "TestClass",
          message: "Class not found"
        )
      end

      it "includes error in summary" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["summary"]["valid"]).to be false
        expect(data["summary"]["error_count"]).to eq(1)
        expect(data["summary"]["total_messages"]).to eq(1)
      end

      it "includes error details in messages array" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["messages"]).to be_an(Array)
        expect(data["messages"].size).to eq(1)

        msg = data["messages"].first
        expect(msg["severity"]).to eq("error")
        expect(msg["category"]).to eq("missing_reference")
        expect(msg["entity_type"]).to eq("class")
        expect(msg["entity_id"]).to eq("123")
        expect(msg["entity_name"]).to eq("TestClass")
        expect(msg["message"]).to eq("Class not found")
      end

      it "groups by category" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["by_category"]).to have_key("missing_reference")
        category_data = data["by_category"]["missing_reference"]
        expect(category_data["count"]).to eq(1)
        expect(category_data["messages"]).to include("Class not found")
      end

      it "groups by severity" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["by_severity"]["errors"]["count"]).to eq(1)
        expect(data["by_severity"]["errors"]["by_category"]).to have_key("missing_reference")
      end
    end

    context "with warnings" do
      before do
        result.add_warning(
          category: :missing_documentation,
          entity_type: :class,
          entity_id: "456",
          entity_name: "UndocumentedClass",
          message: "Class lacks documentation"
        )
      end

      it "includes warning in summary" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["summary"]["warning_count"]).to eq(1)
      end

      it "groups warnings separately" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["by_severity"]["warnings"]["count"]).to eq(1)
      end
    end

    context "with pretty printing" do
      it "formats JSON with indentation" do
        result.add_error(
          category: :missing_reference,
          entity_type: :class,
          entity_id: "123",
          entity_name: "TestClass",
          message: "Test error"
        )

        formatter = described_class.new(result: result, pretty: true)
        output = formatter.format

        # Pretty printed JSON should have newlines and indentation
        expect(output).to include("\n")
        expect(output.lines.count).to be > 5
      end

      it "produces same data as non-pretty" do
        result.add_error(
          category: :missing_reference,
          entity_type: :class,
          entity_id: "123",
          entity_name: "TestClass",
          message: "Test error"
        )

        pretty_formatter = described_class.new(result: result, pretty: true)
        compact_formatter = described_class.new(result: result, pretty: false)

        pretty_data = JSON.parse(pretty_formatter.format)
        compact_data = JSON.parse(compact_formatter.format)

        expect(pretty_data).to eq(compact_data)
      end
    end

    context "with mixed messages" do
      before do
        result.add_error(
          category: :missing_reference,
          entity_type: :class,
          entity_id: "1",
          entity_name: "ErrorClass",
          message: "Critical error"
        )
        result.add_warning(
          category: :missing_documentation,
          entity_type: :class,
          entity_id: "2",
          entity_name: "WarningClass",
          message: "Minor warning"
        )
        result.add_info(
          category: :usage_tip,
          entity_type: :package,
          entity_id: "3",
          entity_name: "InfoPackage",
          message: "Helpful tip"
        )
      end

      it "includes all severities in summary" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["summary"]["error_count"]).to eq(1)
        expect(data["summary"]["warning_count"]).to eq(1)
        expect(data["summary"]["info_count"]).to eq(1)
        expect(data["summary"]["total_messages"]).to eq(3)
      end

      it "separates by severity" do
        formatter = described_class.new(result: result)
        output = formatter.format
        data = JSON.parse(output)

        expect(data["by_severity"]["errors"]["count"]).to eq(1)
        expect(data["by_severity"]["warnings"]["count"]).to eq(1)
        expect(data["by_severity"]["info"]["count"]).to eq(1)
      end
    end
  end
end