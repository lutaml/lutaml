# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/factory/reference_resolver"

RSpec.describe Lutaml::Qea::Factory::ReferenceResolver do
  let(:resolver) { described_class.new }

  # Mock UML element with xmi_id
  let(:mock_element) do
    double("UmlElement", xmi_id: "{GUID-1234-5678}", name: "TestClass")
  end

  let(:mock_element2) do
    double("UmlElement", xmi_id: "{GUID-ABCD-EFGH}", name: "TestClass2")
  end

  describe "#initialize" do
    it "creates empty resolver" do
      expect(resolver).to be_a(described_class)
      expect(resolver.stats[:total_elements]).to eq(0)
      expect(resolver.stats[:total_objects]).to eq(0)
    end
  end

  describe "#register" do
    it "registers EA GUID to UML element mapping" do
      resolver.register("{GUID-1234-5678}", mock_element)
      expect(resolver.resolve("{GUID-1234-5678}")).to eq(mock_element)
    end

    it "normalizes GUID (removes braces, upcases)" do
      resolver.register("{guid-1234-5678}", mock_element)
      expect(resolver.resolve("GUID-1234-5678")).to eq(mock_element)
      expect(resolver.resolve("{GUID-1234-5678}")).to eq(mock_element)
      expect(resolver.resolve("guid-1234-5678")).to eq(mock_element)
    end

    it "handles nil GUID gracefully" do
      expect { resolver.register(nil, mock_element) }.not_to raise_error
      expect(resolver.stats[:total_elements]).to eq(0)
    end

    it "handles nil element gracefully" do
      expect { resolver.register("{GUID-1234}", nil) }.not_to raise_error
      expect(resolver.stats[:total_elements]).to eq(0)
    end

    it "can register multiple elements" do
      resolver.register("{GUID-1234}", mock_element)
      resolver.register("{GUID-ABCD}", mock_element2)

      expect(resolver.stats[:total_elements]).to eq(2)
      expect(resolver.resolve("{GUID-1234}")).to eq(mock_element)
      expect(resolver.resolve("{GUID-ABCD}")).to eq(mock_element2)
    end
  end

  describe "#register_object_name" do
    it "registers object ID to name mapping" do
      resolver.register_object_name(123, "Building")
      expect(resolver.resolve_object_name(123)).to eq("Building")
    end

    it "handles nil object ID gracefully" do
      expect { resolver.register_object_name(nil, "Test") }.not_to raise_error
      expect(resolver.stats[:total_objects]).to eq(0)
    end

    it "can register multiple object names" do
      resolver.register_object_name(123, "Building")
      resolver.register_object_name(456, "Person")

      expect(resolver.stats[:total_objects]).to eq(2)
      expect(resolver.resolve_object_name(123)).to eq("Building")
      expect(resolver.resolve_object_name(456)).to eq("Person")
    end
  end

  describe "#resolve" do
    before do
      resolver.register("{GUID-1234-5678}", mock_element)
    end

    it "resolves registered GUID" do
      expect(resolver.resolve("{GUID-1234-5678}")).to eq(mock_element)
    end

    it "normalizes GUID before resolving" do
      expect(resolver.resolve("guid-1234-5678")).to eq(mock_element)
      expect(resolver.resolve("GUID-1234-5678")).to eq(mock_element)
    end

    it "returns nil for unregistered GUID" do
      expect(resolver.resolve("{UNKNOWN-GUID}")).to be_nil
    end

    it "returns nil for nil GUID" do
      expect(resolver.resolve(nil)).to be_nil
    end
  end

  describe "#resolve_object_name" do
    before do
      resolver.register_object_name(123, "Building")
    end

    it "resolves registered object ID" do
      expect(resolver.resolve_object_name(123)).to eq("Building")
    end

    it "returns nil for unregistered ID" do
      expect(resolver.resolve_object_name(999)).to be_nil
    end

    it "returns nil for nil ID" do
      expect(resolver.resolve_object_name(nil)).to be_nil
    end
  end

  describe "#resolve_xmi_id" do
    before do
      resolver.register("{GUID-1234}", mock_element)
    end

    it "returns xmi_id of resolved element" do
      expect(resolver.resolve_xmi_id("{GUID-1234}")).to eq("{GUID-1234-5678}")
    end

    it "returns nil for unregistered GUID" do
      expect(resolver.resolve_xmi_id("{UNKNOWN}")).to be_nil
    end

    it "returns nil for nil GUID" do
      expect(resolver.resolve_xmi_id(nil)).to be_nil
    end
  end

  describe "#registered?" do
    before do
      resolver.register("{GUID-1234}", mock_element)
    end

    it "returns true for registered GUID" do
      expect(resolver.registered?("{GUID-1234}")).to be true
      expect(resolver.registered?("guid-1234")).to be true
    end

    it "returns false for unregistered GUID" do
      expect(resolver.registered?("{UNKNOWN}")).to be false
    end

    it "returns false for nil GUID" do
      expect(resolver.registered?(nil)).to be false
    end
  end

  describe "#clear" do
    before do
      resolver.register("{GUID-1234}", mock_element)
      resolver.register_object_name(123, "Building")
    end

    it "clears all mappings" do
      expect(resolver.stats[:total_elements]).to eq(1)
      expect(resolver.stats[:total_objects]).to eq(1)

      resolver.clear

      expect(resolver.stats[:total_elements]).to eq(0)
      expect(resolver.stats[:total_objects]).to eq(0)
      expect(resolver.resolve("{GUID-1234}")).to be_nil
      expect(resolver.resolve_object_name(123)).to be_nil
    end
  end

  describe "#stats" do
    it "returns statistics about registered elements" do
      stats = resolver.stats
      expect(stats).to have_key(:total_elements)
      expect(stats).to have_key(:total_objects)
      expect(stats[:total_elements]).to eq(0)
      expect(stats[:total_objects]).to eq(0)
    end

    it "reflects current state" do
      resolver.register("{GUID-1}", mock_element)
      resolver.register("{GUID-2}", mock_element2)
      resolver.register_object_name(123, "Building")

      stats = resolver.stats
      expect(stats[:total_elements]).to eq(2)
      expect(stats[:total_objects]).to eq(1)
    end
  end
end