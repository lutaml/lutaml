# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Exports::Openapi do
  let(:schema_set) do
    Lutaml::Jsonschema::SchemaSet.load_from_files(
      fixture_path("person.json"), fixture_path("post.json")
    )
  end

  def document
    JSON.parse(described_class.new(schema_set).render)
  end

  it "emits an OpenAPI 3.1 document with components.schemas" do
    expect(document["openapi"]).to eq("3.1.0")
    expect(document["components"]["schemas"].keys)
      .to include("person", "post")
  end

  it "emits each schema as a JSON Schema object" do
    person = document["components"]["schemas"]["person"]

    expect(person).to include("type", "properties")
    expect(person["properties"]).to have_key("firstName")
  end

  it "uses the first schema title and allows an override" do
    expect(document["info"]["title"]).to eq("Person")
    expect(described_class.new(schema_set, title: "Custom").document)
      .to include("info" => { "title" => "Custom", "version" => "1.0.0" })
  end

  it "exports through the CLI with --format openapi" do
    expect do
      Lutaml::Jsonschema::Cli.start(
        ["export", fixture_path("person.json"), "--format", "openapi"],
      )
    end.to output(/"openapi": "3.1.0"/).to_stdout
  end
end
