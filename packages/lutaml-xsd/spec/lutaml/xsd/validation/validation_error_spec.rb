# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/validation_error"

RSpec.describe Lutaml::Xsd::Validation::ValidationError do
  describe "#initialize" do
    it "initializes with required parameters" do
      error = described_class.new(
        code: "test_error",
        message: "Test message",
      )
      expect(error.code).to eq("test_error")
      expect(error.message).to eq("Test message")
    end

    it "defaults to error severity" do
      error = described_class.new(
        code: "test_error",
        message: "Test message",
      )
      expect(error.severity).to eq(:error)
    end

    it "accepts custom severity" do
      error = described_class.new(
        code: "test_warning",
        message: "Test message",
        severity: :warning,
      )
      expect(error.severity).to eq(:warning)
    end

    it "accepts location parameter" do
      error = described_class.new(
        code: "test_error",
        message: "Test message",
        location: "/root/element[1]",
      )
      expect(error.location).to eq("/root/element[1]")
    end

    it "accepts line_number parameter" do
      error = described_class.new(
        code: "test_error",
        message: "Test message",
        line_number: 42,
      )
      expect(error.line_number).to eq(42)
    end

    it "accepts context parameter" do
      context = { expected: "integer", actual: "string" }
      error = described_class.new(
        code: "type_mismatch",
        message: "Type mismatch",
        context: context,
      )
      expect(error.context).to eq(context)
    end

    it "accepts suggestion parameter" do
      error = described_class.new(
        code: "test_error",
        message: "Test message",
        suggestion: "Try this instead",
      )
      expect(error.suggestion).to eq("Try this instead")
    end

    it "raises ArgumentError for invalid severity" do
      expect do
        described_class.new(
          code: "test_error",
          message: "Test message",
          severity: :invalid,
        )
      end.to raise_error(ArgumentError, /Invalid severity/)
    end
  end

  describe "severity predicates" do
    describe "#error?" do
      it "returns true for error severity" do
        error = described_class.new(
          code: "test", message: "msg", severity: :error,
        )
        expect(error.error?).to be true
      end

      it "returns false for other severities" do
        warning = described_class.new(
          code: "test", message: "msg", severity: :warning,
        )
        expect(warning.error?).to be false
      end
    end

    describe "#warning?" do
      it "returns true for warning severity" do
        warning = described_class.new(
          code: "test", message: "msg", severity: :warning,
        )
        expect(warning.warning?).to be true
      end

      it "returns false for other severities" do
        error = described_class.new(
          code: "test", message: "msg", severity: :error,
        )
        expect(error.warning?).to be false
      end
    end

    describe "#info?" do
      it "returns true for info severity" do
        info = described_class.new(
          code: "test", message: "msg", severity: :info,
        )
        expect(info.info?).to be true
      end

      it "returns false for other severities" do
        error = described_class.new(
          code: "test", message: "msg", severity: :error,
        )
        expect(error.info?).to be false
      end
    end
  end

  describe "#formatted_location" do
    it "returns location when present" do
      error = described_class.new(
        code: "test", message: "msg", location: "/root",
      )
      expect(error.formatted_location).to eq("/root")
    end

    it "returns line number when present" do
      error = described_class.new(
        code: "test", message: "msg", line_number: 42,
      )
      expect(error.formatted_location).to eq("Line 42")
    end

    it "combines line number and location" do
      error = described_class.new(
        code: "test", message: "msg",
        line_number: 42, location: "/root"
      )
      expect(error.formatted_location).to eq("Line 42, /root")
    end

    it "returns unknown location when neither present" do
      error = described_class.new(code: "test", message: "msg")
      expect(error.formatted_location).to eq("(unknown location)")
    end
  end

  describe "#detailed_message" do
    it "includes severity, code, and message" do
      error = described_class.new(
        code: "type_mismatch",
        message: "Invalid type",
        severity: :error,
      )
      msg = error.detailed_message
      expect(msg).to include("[ERROR]")
      expect(msg).to include("type_mismatch")
      expect(msg).to include("Invalid type")
    end

    it "includes location when present" do
      error = described_class.new(
        code: "test",
        message: "msg",
        location: "/root/element[1]",
      )
      msg = error.detailed_message
      expect(msg).to include("Location:")
      expect(msg).to include("/root/element[1]")
    end

    it "includes context when present" do
      error = described_class.new(
        code: "test",
        message: "msg",
        context: { expected: "integer" },
      )
      msg = error.detailed_message
      expect(msg).to include("Context:")
      expect(msg).to include("expected")
    end

    it "includes suggestion when present" do
      error = described_class.new(
        code: "test",
        message: "msg",
        suggestion: "Try this",
      )
      msg = error.detailed_message
      expect(msg).to include("Suggestion:")
      expect(msg).to include("Try this")
    end
  end

  describe "#has_location?" do
    it "returns true when location is set" do
      error = described_class.new(
        code: "test", message: "msg", location: "/root",
      )
      expect(error.has_location?).to be true
    end

    it "returns true when line_number is set" do
      error = described_class.new(
        code: "test", message: "msg", line_number: 42,
      )
      expect(error.has_location?).to be true
    end

    it "returns false when neither is set" do
      error = described_class.new(code: "test", message: "msg")
      expect(error.has_location?).to be false
    end
  end

  describe "#has_suggestion?" do
    it "returns true when suggestion is set" do
      error = described_class.new(
        code: "test", message: "msg", suggestion: "Try this",
      )
      expect(error.has_suggestion?).to be true
    end

    it "returns false when suggestion is nil" do
      error = described_class.new(code: "test", message: "msg")
      expect(error.has_suggestion?).to be false
    end

    it "returns false when suggestion is empty string" do
      error = described_class.new(
        code: "test", message: "msg", suggestion: "",
      )
      expect(error.has_suggestion?).to be false
    end
  end

  describe "#to_h" do
    it "converts to hash representation" do
      error = described_class.new(
        code: "test_error",
        message: "Test message",
        severity: :error,
        location: "/root",
        line_number: 42,
        context: { key: "value" },
        suggestion: "Fix this",
      )
      hash = error.to_h
      expect(hash[:code]).to eq("test_error")
      expect(hash[:message]).to eq("Test message")
      expect(hash[:severity]).to eq(:error)
      expect(hash[:location]).to eq("/root")
      expect(hash[:line_number]).to eq(42)
      expect(hash[:context]).to eq({ key: "value" })
      expect(hash[:suggestion]).to eq("Fix this")
    end

    it "omits nil values" do
      error = described_class.new(code: "test", message: "msg")
      hash = error.to_h
      expect(hash).not_to have_key(:location)
      expect(hash).not_to have_key(:line_number)
      expect(hash).not_to have_key(:suggestion)
    end
  end

  describe "#to_json" do
    it "converts to JSON string" do
      error = described_class.new(code: "test", message: "msg")
      json = error.to_json
      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed["code"]).to eq("test")
      expect(parsed["message"]).to eq("msg")
    end
  end

  describe "#to_s" do
    it "returns simple string representation" do
      error = described_class.new(
        code: "type_mismatch",
        message: "Invalid type",
        severity: :error,
      )
      str = error.to_s
      expect(str).to include("ERROR")
      expect(str).to include("Invalid type")
      expect(str).to include("type_mismatch")
    end
  end

  describe "#inspect" do
    it "returns detailed inspection string" do
      error = described_class.new(
        code: "test",
        message: "msg",
        location: "/root",
      )
      inspection = error.inspect
      expect(inspection).to include("ValidationError")
      expect(inspection).to include("test")
      expect(inspection).to include("msg")
      expect(inspection).to include("/root")
    end
  end

  describe "#==" do
    let(:error1) do
      described_class.new(
        code: "test",
        message: "msg",
        location: "/root",
      )
    end

    let(:error2) do
      described_class.new(
        code: "test",
        message: "msg",
        location: "/root",
      )
    end

    let(:error3) do
      described_class.new(
        code: "different",
        message: "msg",
        location: "/root",
      )
    end

    it "returns true for equal errors" do
      expect(error1).to eq(error2)
    end

    it "returns false for different errors" do
      expect(error1).not_to eq(error3)
    end

    it "returns false for non-ValidationError objects" do
      expect(error1).not_to eq("not an error")
    end
  end

  describe "#hash" do
    it "returns consistent hash for same content" do
      error1 = described_class.new(
        code: "test", message: "msg", location: "/root",
      )
      error2 = described_class.new(
        code: "test", message: "msg", location: "/root",
      )
      expect(error1.hash).to eq(error2.hash)
    end

    it "allows errors to be used in sets" do
      error1 = described_class.new(
        code: "test", message: "msg", location: "/root",
      )
      error2 = described_class.new(
        code: "test", message: "msg", location: "/root",
      )
      set = Set.new([error1, error2])
      expect(set.size).to eq(1)
    end
  end
end
