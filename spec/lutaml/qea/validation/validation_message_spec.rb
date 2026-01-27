# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/validation_message"

RSpec.describe Lutaml::Qea::Validation::ValidationMessage do
  let(:message_attributes) do
    {
      severity: :error,
      category: :missing_reference,
      entity_type: :class,
      entity_id: "123",
      entity_name: "TestClass",
      field: "parent_id",
      reference: "456",
      message: "parent_id references non-existent package",
      location: "Package::SubPackage",
      context: { table: "t_object" },
    }
  end

  describe "#initialize" do
    it "creates a message with all attributes" do
      msg = described_class.new(**message_attributes)

      expect(msg.severity).to eq(:error)
      expect(msg.category).to eq(:missing_reference)
      expect(msg.entity_type).to eq(:class)
      expect(msg.entity_id).to eq("123")
      expect(msg.entity_name).to eq("TestClass")
      expect(msg.field).to eq("parent_id")
      expect(msg.reference).to eq("456")
      expect(msg.message).to eq("parent_id references non-existent package")
      expect(msg.location).to eq("Package::SubPackage")
      expect(msg.context).to eq({ table: "t_object" })
    end

    it "creates a message without optional fields" do
      msg = described_class.new(
        severity: :warning,
        category: :orphaned,
        entity_type: :association,
        entity_id: "789",
        entity_name: "MyAssociation",
        message: "association is orphaned",
      )

      expect(msg.field).to be_nil
      expect(msg.reference).to be_nil
      expect(msg.location).to be_nil
      expect(msg.context).to eq({})
    end
  end

  describe "severity checks" do
    it "identifies error messages" do
      msg = described_class.new(**message_attributes.merge(severity: :error))
      expect(msg.error?).to be true
      expect(msg.warning?).to be false
      expect(msg.info?).to be false
    end

    it "identifies warning messages" do
      msg = described_class.new(**message_attributes.merge(severity: :warning))
      expect(msg.error?).to be false
      expect(msg.warning?).to be true
      expect(msg.info?).to be false
    end

    it "identifies info messages" do
      msg = described_class.new(**message_attributes.merge(severity: :info))
      expect(msg.error?).to be false
      expect(msg.warning?).to be false
      expect(msg.info?).to be true
    end
  end

  describe "#to_s" do
    it "returns a formatted string representation" do
      msg = described_class.new(**message_attributes)
      result = msg.to_s

      expect(result).to include("Class 'TestClass'")
      expect(result).to include("{123}")
      expect(result).to include("parent_id references non-existent package")
      expect(result).to include("Field: parent_id")
      expect(result).to include("Reference: 456")
      expect(result).to include("Location: Package::SubPackage")
    end

    it "handles missing optional fields" do
      msg = described_class.new(
        severity: :info,
        category: :orphaned,
        entity_type: :package,
        entity_id: "999",
        entity_name: "EmptyPackage",
        message: "package contains no elements",
      )
      result = msg.to_s

      expect(result).to include("Package 'EmptyPackage'")
      expect(result).not_to include("Field:")
      expect(result).not_to include("Reference:")
      expect(result).not_to include("Location:")
    end
  end

  describe "#to_h" do
    it "returns a hash representation with all fields" do
      msg = described_class.new(**message_attributes)
      hash = msg.to_h

      expect(hash[:severity]).to eq(:error)
      expect(hash[:category]).to eq(:missing_reference)
      expect(hash[:entity_type]).to eq(:class)
      expect(hash[:entity_id]).to eq("123")
      expect(hash[:entity_name]).to eq("TestClass")
      expect(hash[:field]).to eq("parent_id")
      expect(hash[:reference]).to eq("456")
      expect(hash[:message]).to eq("parent_id references non-existent package")
      expect(hash[:location]).to eq("Package::SubPackage")
      expect(hash[:context]).to eq({ table: "t_object" })
    end

    it "omits nil optional fields" do
      msg = described_class.new(
        severity: :info,
        category: :orphaned,
        entity_type: :package,
        entity_id: "999",
        entity_name: "EmptyPackage",
        message: "package contains no elements",
      )
      hash = msg.to_h

      expect(hash).not_to have_key(:field)
      expect(hash).not_to have_key(:reference)
      expect(hash).not_to have_key(:location)
    end
  end

  describe "#to_json" do
    it "returns a JSON representation" do
      msg = described_class.new(**message_attributes)
      json = msg.to_json
      parsed = JSON.parse(json)

      expect(parsed["severity"]).to eq("error")
      expect(parsed["category"]).to eq("missing_reference")
      expect(parsed["entity_type"]).to eq("class")
      expect(parsed["entity_id"]).to eq("123")
      expect(parsed["entity_name"]).to eq("TestClass")
    end
  end
end
