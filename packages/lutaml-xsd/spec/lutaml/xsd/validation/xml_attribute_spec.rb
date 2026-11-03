# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/xml_attribute"

RSpec.describe Lutaml::Xsd::Validation::XmlAttribute do
  describe "#initialize" do
    it "creates an attribute with name and value" do
      attr = described_class.new("id", "12345")

      expect(attr.name).to eq("id")
      expect(attr.value).to eq("12345")
      expect(attr.namespace_uri).to be_nil
      expect(attr.prefix).to be_nil
    end

    it "creates an attribute with namespace" do
      attr = described_class.new("type", "string", "http://www.w3.org/2001/XMLSchema")

      expect(attr.name).to eq("type")
      expect(attr.value).to eq("string")
      expect(attr.namespace_uri).to eq("http://www.w3.org/2001/XMLSchema")
    end

    it "creates an attribute with prefix" do
      attr = described_class.new("type", "string",
                                 "http://www.w3.org/2001/XMLSchema", "xs")

      expect(attr.prefix).to eq("xs")
    end
  end

  describe "#qualified_name" do
    it "returns Clark notation for namespaced attributes" do
      attr = described_class.new("type", "string", "http://www.w3.org/2001/XMLSchema")

      expect(attr.qualified_name).to eq("{http://www.w3.org/2001/XMLSchema}type")
    end

    it "returns local name for non-namespaced attributes" do
      attr = described_class.new("id", "12345")

      expect(attr.qualified_name).to eq("id")
    end

    it "returns local name when namespace is empty string" do
      attr = described_class.new("id", "12345", "")

      expect(attr.qualified_name).to eq("id")
    end
  end

  describe "#prefixed_name" do
    it "returns prefixed name when prefix is present" do
      attr = described_class.new("type", "string",
                                 "http://www.w3.org/2001/XMLSchema", "xs")

      expect(attr.prefixed_name).to eq("xs:type")
    end

    it "returns local name when no prefix" do
      attr = described_class.new("id", "12345")

      expect(attr.prefixed_name).to eq("id")
    end

    it "returns local name when prefix is empty string" do
      attr = described_class.new("id", "12345", nil, "")

      expect(attr.prefixed_name).to eq("id")
    end
  end

  describe "#namespaced?" do
    it "returns true for namespaced attributes" do
      attr = described_class.new("type", "string", "http://www.w3.org/2001/XMLSchema")

      expect(attr.namespaced?).to be true
    end

    it "returns false for non-namespaced attributes" do
      attr = described_class.new("id", "12345")

      expect(attr.namespaced?).to be false
    end

    it "returns false when namespace is empty string" do
      attr = described_class.new("id", "12345", "")

      expect(attr.namespaced?).to be false
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      attr = described_class.new("type", "string",
                                 "http://www.w3.org/2001/XMLSchema", "xs")
      hash = attr.to_h

      expect(hash[:name]).to eq("type")
      expect(hash[:value]).to eq("string")
      expect(hash[:namespace_uri]).to eq("http://www.w3.org/2001/XMLSchema")
      expect(hash[:prefix]).to eq("xs")
      expect(hash[:qualified_name]).to eq("{http://www.w3.org/2001/XMLSchema}type")
    end

    it "excludes nil values" do
      attr = described_class.new("id", "12345")
      hash = attr.to_h

      expect(hash).not_to have_key(:namespace_uri)
      expect(hash).not_to have_key(:prefix)
    end
  end

  describe "#to_s" do
    it "returns string representation with prefix" do
      attr = described_class.new("type", "string",
                                 "http://www.w3.org/2001/XMLSchema", "xs")

      expect(attr.to_s).to eq('xs:type="string"')
    end

    it "returns string representation without prefix" do
      attr = described_class.new("id", "12345")

      expect(attr.to_s).to eq('id="12345"')
    end
  end

  describe "#==" do
    it "returns true for equal attributes" do
      attr1 = described_class.new("id", "12345")
      attr2 = described_class.new("id", "12345")

      expect(attr1).to eq(attr2)
    end

    it "returns true for equal namespaced attributes" do
      attr1 = described_class.new("type", "string", "http://www.w3.org/2001/XMLSchema")
      attr2 = described_class.new("type", "string", "http://www.w3.org/2001/XMLSchema")

      expect(attr1).to eq(attr2)
    end

    it "returns false for different names" do
      attr1 = described_class.new("id", "12345")
      attr2 = described_class.new("name", "12345")

      expect(attr1).not_to eq(attr2)
    end

    it "returns false for different values" do
      attr1 = described_class.new("id", "12345")
      attr2 = described_class.new("id", "67890")

      expect(attr1).not_to eq(attr2)
    end

    it "returns false for different namespaces" do
      attr1 = described_class.new("type", "string", "http://www.w3.org/2001/XMLSchema")
      attr2 = described_class.new("type", "string", "http://example.com")

      expect(attr1).not_to eq(attr2)
    end

    it "returns false when comparing with non-XmlAttribute" do
      attr = described_class.new("id", "12345")

      expect(attr).not_to eq('id="12345"')
    end
  end

  describe "#hash" do
    it "returns same hash for equal attributes" do
      attr1 = described_class.new("id", "12345")
      attr2 = described_class.new("id", "12345")

      expect(attr1.hash).to eq(attr2.hash)
    end

    it "allows use in sets" do
      attr1 = described_class.new("id", "12345")
      attr2 = described_class.new("id", "12345")
      attr3 = described_class.new("name", "test")

      set = Set.new([attr1, attr2, attr3])

      expect(set.size).to eq(2)
    end
  end
end
