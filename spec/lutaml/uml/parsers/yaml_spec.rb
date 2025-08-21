# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Parsers::Yaml do
  describe ".parse" do
    subject(:parse) { described_class.parse(yaml_path) }

    let(:yaml_path) do
      fixtures_path("uml/document.yml")
    end

    let(:output) { parse.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: TestDocument
        title: Test Document Title
        groups:
        - id: TestGroup1
          values:
          - TestGroup1a
          - TestGroup1b
        - id: TestGroup2
          values:
          - TestGroup2a
          - TestGroup2b
          - TestGroup2c
          groups:
          - id: TestSubGroup1
            values:
            - TestSubGroup1a
            - TestSubGroup1b
        enums:
        - name: TestEnum
          keyword: enumeration
          visibility: public
          definition: |-
            This is a test definition.
            It spans multiple lines.
            It should be formatted correctly.
          full_name: TestEnum
          attributes:
          - name: TestAttribute
            visibility: private
            cardinality:
              min: '1'
              max: "*"
            is_derived: false
          values:
          - name: Test value
        packages:
        - name: Package
          visibility: public
          full_name: Package
          contents:
          - This is a nested package content.
          packages:
          - name: NestedPackage
            visibility: public
            full_name: NestedPackage
            contents:
            - This is a nested package content.
            packages:
            - name: DeepNestedPackage
              visibility: public
              full_name: DeepNestedPackage
              contents:
              - This is a deep nested package content.
      YAML
    end

    it "creates Lutaml::Uml::Document object" do
      expect(parse).to be_instance_of(Lutaml::Uml::Document)
    end

    it "contains nested groups" do
      expect(YAML.safe_load(output)["groups"]).to be_an(Array)
      expect(YAML.safe_load(output)["groups"].size).to eq(2)
      expect(YAML.safe_load(output)["groups"].first["id"]).to eq("TestGroup1")
      expect(YAML.safe_load(output)["groups"].first["values"])
        .to eq(["TestGroup1a", "TestGroup1b"])
      expect(YAML.safe_load(output)["groups"][1]["id"]).to eq("TestGroup2")
      expect(YAML.safe_load(output)["groups"][1]["values"])
        .to eq(["TestGroup2a", "TestGroup2b", "TestGroup2c"])
      expect(YAML.safe_load(output)["groups"][1]["groups"]).to be_an(Array)
      expect(YAML.safe_load(output)["groups"][1]["groups"].size).to eq(1)
      expect(YAML.safe_load(output)["groups"][1]["groups"].first["id"])
        .to eq("TestSubGroup1")
    end

    it "outputs full yaml" do
      expect(output).to eq(expected_output)
    end
  end
end
