# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::TopElement do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/top_element.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: This is a test
        namespace:
          name: TestNamespace
          namespace:
            name: NestedNamespace
        visibility: private
        definition: |-
          This is a test definition.
          It spans multiple lines.
          It should be formatted correctly.
        full_name: NestedNamespace::TestNamespace::This is a test
      YAML
    end

    it "outputs full name with namespaces" do
      expect(YAML.safe_load(output)["full_name"])
        .to eq("NestedNamespace::TestNamespace::This is a test")
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
