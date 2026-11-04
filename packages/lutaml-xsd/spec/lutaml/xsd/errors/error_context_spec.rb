# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/errors/error_context"

RSpec.describe Lutaml::Xsd::Errors::ErrorContext do
  describe "#initialize" do
    it "creates context with all attributes" do
      context = described_class.new(
        location: "/root/element",
        namespace: "http://example.com",
        expected_type: "xs:string",
        actual_value: "123",
      )

      expect(context.location).to eq("/root/element")
      expect(context.namespace).to eq("http://example.com")
      expect(context.expected_type).to eq("xs:string")
      expect(context.actual_value).to eq("123")
    end

    it "stores additional attributes" do
      context = described_class.new(
        location: "/root",
        custom_field: "custom_value",
      )

      expect(context.additional).to eq({ custom_field: "custom_value" })
    end

    it "accepts repository" do
      repository = double("repository")
      context = described_class.new(repository: repository)

      expect(context.repository).to eq(repository)
    end
  end

  describe "#to_h" do
    it "converts context to hash" do
      context = described_class.new(
        location: "/root/element",
        namespace: "http://example.com",
        expected_type: "xs:string",
        actual_value: "123",
      )

      hash = context.to_h
      expect(hash[:location]).to eq("/root/element")
      expect(hash[:namespace]).to eq("http://example.com")
      expect(hash[:expected_type]).to eq("xs:string")
      expect(hash[:actual_value]).to eq("123")
    end

    it "includes additional attributes" do
      context = described_class.new(
        location: "/root",
        custom: "value",
      )

      hash = context.to_h
      expect(hash[:custom]).to eq("value")
    end

    it "omits nil values" do
      context = described_class.new(location: "/root")

      hash = context.to_h
      expect(hash).to eq({ location: "/root" })
    end
  end

  describe "#has_repository?" do
    it "returns true when repository is present" do
      repository = double("repository")
      context = described_class.new(repository: repository)

      expect(context.has_repository?).to be true
    end

    it "returns false when repository is nil" do
      context = described_class.new

      expect(context.has_repository?).to be false
    end
  end
end
