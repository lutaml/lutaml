# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Association do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/association.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        visibility: public
        owner_end: _Curve
        owner_end_xmi_id: EAID_83B2B411_0579_4e2d_823D_D22BF0F06064
        member_end: MultiCurve
        member_end_attribute_name: MultiCurve
        member_end_xmi_id: EAID_B326682E_0384_443a_A119_96FD046071A2
        member_end_cardinality:
          min: '1'
          max: "*"
        member_end_type: association
      YAML
    end

    it "outputs owner_end" do
      expect(YAML.safe_load(output)["owner_end"])
        .to eq("_Curve")
    end

    it "outputs default owner_end_xmi_id" do
      expect(YAML.safe_load(output)["owner_end_xmi_id"])
        .to eq("EAID_83B2B411_0579_4e2d_823D_D22BF0F06064")
    end

    it "outputs full yaml" do
      expect(output).to eq(expected_output)
    end
  end
end