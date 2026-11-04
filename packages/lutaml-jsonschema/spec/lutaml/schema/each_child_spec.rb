# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Schema, "#each_child" do
  it "yields property entry schemas" do
    schema = described_class.from_json(JSON.generate({
                                                       "properties" => {
                                                         "name" => { "type" => "string" },
                                                         "age" => { "type" => "integer" },
                                                       },
                                                     }))
    children = schema.each_child.to_a
    paths = children.map { |_, path| path }
    expect(paths).to contain_exactly("properties/name", "properties/age")
  end

  it "yields definition entry schemas" do
    schema = described_class.from_json(JSON.generate({
                                                       "$defs" => {
                                                         "email" => {
                                                           "type" => "string", "format" => "email"
                                                         },
                                                       },
                                                     }))
    children = schema.each_child.to_a
    expect(children.length).to eq(1)
    expect(children.first[1]).to eq("$defs/email")
    expect(children.first[0].format).to eq("email")
  end

  it "yields composition schemas with indexed paths" do
    schema = described_class.from_json(JSON.generate({
                                                       "allOf" => [
                                                         { "type" => "object" },
                                                         { "type" => "string" },
                                                       ],
                                                       "oneOf" => [{ "type" => "integer" }],
                                                     }))
    children = schema.each_child.to_a
    paths = children.map { |_, path| path }
    expect(paths).to contain_exactly("allOf[0]", "allOf[1]", "oneOf[0]")
  end

  it "yields single-child schemas" do
    schema = described_class.from_json(JSON.generate({
                                                       "items" => { "type" => "string" },
                                                       "not" => { "type" => "integer" },
                                                     }))
    children = schema.each_child.to_a
    paths = children.map { |_, path| path }
    expect(paths).to contain_exactly("items", "not")
  end

  it "yields tuple item schemas positionally" do
    schema = described_class.from_json(JSON.generate({
                                                       "items" => [
                                                         { "type" => "string" },
                                                         { "type" => "integer" },
                                                       ],
                                                     }))
    children = schema.each_child.to_a

    expect(children.map { |_, path| path }).to eq(%w[items[0] items[1]])
    expect(schema.child_at("items").map(&:type)).to eq(%w[string integer])
  end

  it "skips boolean schemas, which have no children" do
    schema = described_class.from_json(JSON.generate({
                                                       "properties" => { "a" => true },
                                                       "$defs" => { "b" => false },
                                                     }))

    expect(schema.each_child.to_a).to eq([])
  end

  it "skips boolean prefixItems entries" do
    schema = described_class.from_json(JSON.generate({
                                                       "prefixItems" => [
                                                         true,
                                                         { "type" => "string" },
                                                       ],
                                                     }))

    expect(schema.each_child.map { |_, path| path }).to eq(["prefixItems[1]"])
  end

  it "yields conditional schemas" do
    schema = described_class.from_json(JSON.generate({
                                                       "if" => { "properties" => { "x" => { "type" => "string" } } },
                                                       "then" => { "required" => ["x"] },
                                                       "else" => { "required" => ["y"] },
                                                     }))
    children = schema.each_child.to_a
    paths = children.map { |_, path| path }
    expect(paths).to contain_exactly("if", "then", "else")
  end

  it "yields link schemas" do
    schema = described_class.from_json(JSON.generate({
                                                       "links" => [
                                                         {
                                                           "href" => "/items",
                                                           "method" => "POST",
                                                           "schema" => { "type" => "object" },
                                                           "targetSchema" => { "type" => "array" },
                                                         },
                                                       ],
                                                     }))
    children = schema.each_child.to_a
    paths = children.map { |_, path| path }
    expect(paths).to contain_exactly("link.schema", "link.target_schema")
  end

  it "yields pattern property schemas" do
    schema = described_class.from_json(JSON.generate({
                                                       "patternProperties" => {
                                                         "^S_" => { "type" => "string" },
                                                       },
                                                     }))
    children = schema.each_child.to_a
    expect(children.first[1]).to eq("patternProperties/^S_")
  end

  it "returns an enumerator when no block given" do
    schema = described_class.from_json(JSON.generate({
                                                       "properties" => { "a" => { "type" => "string" } },
                                                     }))
    enum = schema.each_child
    expect(enum).to be_a(Enumerator)
    expect(enum.count).to eq(1)
  end
end

RSpec.describe Lutaml::Jsonschema::Schema, "#child_at" do
  it "returns property_entries for 'properties'" do
    schema = described_class.from_json(JSON.generate({
                                                       "properties" => { "name" => { "type" => "string" } },
                                                     }))
    result = schema.child_at("properties")
    expect(result).to be_a(Array)
    expect(result.length).to eq(1)
    expect(result.first.name).to eq("name")
  end

  it "returns definition_entries for 'definitions' and '$defs'" do
    schema = described_class.from_json(JSON.generate({
                                                       "$defs" => { "email" => { "type" => "string" } },
                                                     }))
    expect(schema.child_at("definitions")).to eq(schema.definition_entries)
    expect(schema.child_at("$defs")).to eq(schema.definition_entries)
  end

  it "returns items schema for 'items'" do
    schema = described_class.from_json(JSON.generate({
                                                       "items" => { "type" => "string" },
                                                     }))
    expect(schema.child_at("items").type).to eq("string")
  end

  it "returns all_of array for 'allOf'" do
    schema = described_class.from_json(JSON.generate({
                                                       "allOf" => [{ "type" => "object" }],
                                                     }))
    expect(schema.child_at("allOf").length).to eq(1)
  end

  it "returns not_schema for 'not'" do
    schema = described_class.from_json(JSON.generate({
                                                       "not" => { "type" => "string" },
                                                     }))
    expect(schema.child_at("not").type).to eq("string")
  end

  it "resolves named definition entry for arbitrary segment" do
    schema = described_class.from_json(JSON.generate({
                                                       "$defs" => { "address" => { "type" => "object" } },
                                                     }))
    result = schema.child_at("address")
    expect(result).to be_a(described_class)
    expect(result.type).to eq("object")
  end

  it "returns nil for unknown segment" do
    schema = described_class.new
    expect(schema.child_at("nonexistent")).to be_nil
  end
end
