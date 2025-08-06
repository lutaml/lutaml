# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::DataType do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/data_type.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: TestDataType
        namespace:
          name: TestNamespace
          namespace:
            name: NestedNamespace
        keyword: dataType
        visibility: public
        definition: |-
          This is a test definition.
          It spans multiple lines.
          It should be formatted correctly.
        full_name: NestedNamespace::TestNamespace::TestDataType
        is_abstract: false
        operations:
        - name: TestOperation1
          visibility: public
          definition: |-
            This is a test definition.
            It spans multiple lines.
            It should be formatted correctly.
          full_name: TestOperation1
          return_type: TestReturnType1
          parameter_type: TestParameter1
        - name: TestOperation2
          visibility: public
          definition: |-
            This is a test definition 2.
            It spans multiple lines.
            It should be formatted correctly.
          full_name: TestOperation2
          return_type: TestReturnType2
          parameter_type: TestParameter2
        associations:
        - visibility: public
          owner_end: TestDataType
          member_end: TestAssociation
          member_end_cardinality:
            min: '1'
            max: "*"
      YAML
    end

    it "outputs default keyword" do
      expect(YAML.safe_load(output)["keyword"])
        .to eq("dataType")
    end

    it "outputs full name with namespaces" do
      expect(YAML.safe_load(output)["full_name"])
        .to eq("NestedNamespace::TestNamespace::TestDataType")
    end

    it "outputs associations with owner_end" do
      expect(YAML.safe_load(output)["associations"].first["owner_end"])
        .to eq("TestDataType")
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
