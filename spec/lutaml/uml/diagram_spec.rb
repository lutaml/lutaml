# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Diagram do
  describe ".from_yaml" do
    subject(:test_model) { described_class.from_yaml(yaml_content) }

    let(:yaml_content) do
      File.read(fixtures_path("uml/diagram.yml"))
    end

    let(:output) { test_model.to_yaml }

    let(:expected_output) do
      <<~YAML
        ---
        name: gml
        xmi_id: EAID_7854470F_26B8_4d3c_AFDF_C05BCE6ED0CD
        visibility: public
        package_id: EAPK_939925FF_6235_4286_82FF_7392B33F305C
        package_name: gml
      YAML
    end

    it "outputs name" do
      expect(YAML.safe_load(output)["name"]).to eq("gml")
    end

    it "outputs full yaml" do
      expect(output).to eq(expected_output)
    end
  end
end
