# frozen_string_literal: true

require "spec_helper"

RSpec.describe "externalDocs support" do
  let(:docs) do
    { "url" => "https://example.org/docs", "description" => "Full docs" }
  end

  def parse(hash)
    Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash))
  end

  it "round-trips externalDocs through the model" do
    schema = parse("title" => "T", "externalDocs" => docs)

    expect(schema.external_docs).to eq(docs)
    expect(Yeptris::JSON.load(schema.to_json)["externalDocs"]).to eq(docs)
  end

  it "projects externalDocs into the SPA document" do
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", parse("title" => "T", "externalDocs" => docs))

    doc = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build
    schema = doc.schemas.first

    expect(schema.external_docs).to eq(docs)
    expect(Yeptris::JSON.load(doc.to_json)["schemas"][0]["externalDocs"])
      .to eq(docs)
  end

  it "leaves externalDocs absent when not declared" do
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", parse("title" => "T"))

    doc = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build

    expect(doc.schemas.first.external_docs).to be_nil
    expect(Yeptris::JSON.load(doc.to_json)["schemas"][0])
      .not_to have_key("externalDocs")
  end
end
