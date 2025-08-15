# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Value do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/value.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: This is a test
        id: '111'
        type: TestType
        definition: |-
          This is a test definition.
          It spans multiple lines.
          It should be formatted correctly.
      YAML
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
