# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::TopElementAttribute do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/top_element_attribute.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: This is a test
        visibility: private
        cardinality:
          min: '1'
          max: "*"
        is_derived: false
        definition: |-
          This is a test definition.
          It spans multiple lines.
          It should be formatted correctly.
      YAML
    end

    it "outputs cardinality" do
      expect(YAML.safe_load(output)["cardinality"]["min"]).to eq("1")
      expect(YAML.safe_load(output)["cardinality"]["max"]).to eq("*")
    end

    it "outputs default is_derived" do
      expect(YAML.safe_load(output)["is_derived"]).to eq(false)
    end

    it "outputs stripped definition" do
      expect(YAML.safe_load(output)["definition"])
        .to eq("This is a test definition.\n" \
               "It spans multiple lines.\n" \
               "It should be formatted correctly.")
    end

    it "outputs full yaml" do
      expect(output).to eq(expected_output)
    end
  end
end
