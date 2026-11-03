# frozen_string_literal: true

require "spec_helper"

RSpec.describe "sort_properties configuration (Redoc sort options)" do
  def build_set
    schema = Lutaml::Jsonschema::Schema.from_json(
      Yeptris::JSON.dump({
                           "type" => "object",
                           "required" => %w[beta],
                           "properties" => {
                             "zeta" => { "type" => "string" },
                             "alpha" => { "type" => "string" },
                             "beta" => { "type" => "string" },
                           },
                         }),
    )
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", schema)
    set
  end

  def property_names(sort_properties)
    metadata = Lutaml::Jsonschema::Spa::Metadata.new(
      sort_properties: sort_properties,
    )
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(
      build_set, metadata: metadata
    ).build
    document.schemas.first.properties.map(&:name)
  end

  it "keeps source order by default" do
    expect(property_names(nil)).to eq(%w[zeta alpha beta])
  end

  it "sorts alphabetically" do
    expect(property_names("alphabetical")).to eq(%w[alpha beta zeta])
  end

  it "puts required properties first, preserving order within groups" do
    expect(property_names("required_first")).to eq(%w[beta zeta alpha])
  end

  it "ignores unknown values" do
    expect(property_names("diagonal")).to eq(%w[zeta alpha beta])
  end

  it "parses sort_properties from the YAML configuration" do
    config = Lutaml::Jsonschema::Configuration.from_yaml(
      "sort_properties: required_first\n",
    )

    expect(config.sort_properties).to eq("required_first")
    expect(config.to_metadata.sort_properties).to eq("required_first")
  end
end
