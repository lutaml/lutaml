# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/search_result"

RSpec.describe Lutaml::UmlRepository::SearchResult do
  let(:mock_element) { double("UML Element", name: "TestClass") }
  let(:result) do
    described_class.new(
      element: mock_element,
      element_type: :class,
      qualified_name: "ModelRoot::Package::TestClass",
      package_path: "ModelRoot::Package",
      match_field: :name,
      match_context: { query: "Test" },
    )
  end

  describe "#initialize" do
    it "creates a frozen instance" do
      expect(result).to be_frozen
    end

    it "sets all attributes correctly", :aggregate_failures do
      expect(result.element).to eq(mock_element)
      expect(result.element_type).to eq("class")
      expect(result.qualified_name).to eq("ModelRoot::Package::TestClass")
      expect(result.package_path).to eq("ModelRoot::Package")
      expect(result.match_field).to eq("name")
      expect(result.match_context).to eq({ query: "Test" })
    end

    it "allows nil match_context" do
      result_without_context = described_class.new(
        element: mock_element,
        element_type: :class,
        qualified_name: "TestClass",
        package_path: "",
        match_field: :name,
      )
      expect(result_without_context.match_context).to eq({})
    end
  end

  describe "#to_yaml_hash" do
    it "returns hash representation", :aggregate_failures do
      hash = result.to_yaml_hash
      expect(hash).to be_a(Hash)
      expect(hash["element_type"]).to eq("class")
      expect(hash["qualified_name"]).to eq("ModelRoot::Package::TestClass")
      expect(hash["package_path"]).to eq("ModelRoot::Package")
      expect(hash["match_field"]).to eq("name")
      expect(hash["match_context"]).to eq({ query: "Test" })
    end

    it "converts symbols to strings", :aggregate_failures do
      hash = result.to_yaml_hash
      expect(hash["element_type"]).to be_a(String)
      expect(hash["match_field"]).to be_a(String)
    end
  end

  describe "immutability" do
    it "cannot modify element after creation" do
      expect { result.instance_variable_set(:@element, "new") }
        .to raise_error(FrozenError)
    end

    it "cannot modify element_type after creation" do
      expect { result.instance_variable_set(:@element_type, :other) }
        .to raise_error(FrozenError)
    end
  end
end
