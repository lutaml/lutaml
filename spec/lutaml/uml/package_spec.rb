# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Package do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/package.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: TestPackage
        visibility: public
        full_name: TestPackage
        contents:
        - This is a package content.
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
      YAML
    end

    it "contains nested packages" do
      expect(YAML.safe_load(output)["packages"]).to be_an(Array)
      expect(YAML.safe_load(output)["packages"].size).to eq(1)
      expect(YAML.safe_load(output)["packages"].first["name"])
        .to eq("NestedPackage")
      expect(YAML.safe_load(output)["packages"].first["packages"])
        .to be_an(Array)
      expect(YAML.safe_load(output)["packages"].first["packages"].size).to eq(1)
      expect(
        YAML.safe_load(output)["packages"].first["packages"].first["name"],
      ).to eq("DeepNestedPackage")
    end

    it "contains children_packages" do
      expect(test_model.children_packages.count).to eq(2)
      expect(test_model.children_packages.first).to be_instance_of(Lutaml::Uml::Package)
    end

    it "outputs full yaml" do
      expect(output).to eq(expected_output)
    end
  end
end
