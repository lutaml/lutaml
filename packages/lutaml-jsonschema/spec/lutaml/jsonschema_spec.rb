# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema do
  it "has a version number" do
    expect(Lutaml::Jsonschema::VERSION).not_to be nil
  end
end

RSpec.describe Lutaml::Jsonschema::Schema do
  let(:person_json) do
    File.read(File.join(__dir__, "..", "fixtures", "person.json"))
  end

  describe ".from_json (parsing)" do
    subject(:schema) { described_class.from_json(person_json) }

    it "parses document-level keywords" do
      expect(schema.dollar_schema).to eq("http://json-schema.org/draft-07/schema#")
      expect(schema.dollar_id).to eq("https://example.com/person.schema.json")
    end

    it "parses metadata" do
      expect(schema.title).to eq("Person")
      expect(schema.description).to eq("A person object")
    end

    it "parses type" do
      expect(schema.type).to eq("object")
      expect(schema.types).to eq(["object"])
    end

    it "parses required" do
      expect(schema.required).to contain_exactly("firstName", "lastName")
    end

    it "parses additionalProperties" do
      expect(schema.additional_properties).to eq(false)
    end

    it "parses properties as PropertyEntry collection" do
      expect(schema.property_entries.length).to eq(6)
      names = schema.property_entries.map(&:name)
      expect(names).to contain_exactly("firstName", "lastName", "age", "email",
                                       "tags", "address")
    end

    it "parses nested property schemas" do
      first_name = schema.property_entries.find { |e| e.name == "firstName" }
      expect(first_name.schema.type).to eq("string")
      expect(first_name.schema.description).to eq("The person's first name.")
      expect(first_name.schema.min_length).to eq(1)
      expect(first_name.schema.max_length).to eq(100)
    end

    it "parses integer properties with constraints" do
      age = schema.property_entries.find { |e| e.name == "age" }
      expect(age.schema.type).to eq("integer")
      expect(age.schema.description).to eq("Age in years.")
      expect(age.schema.minimum).to eq(0.0)
    end

    it "parses format" do
      email = schema.property_entries.find { |e| e.name == "email" }
      expect(email.schema.format).to eq("email")
    end

    it "parses array items" do
      tags = schema.property_entries.find { |e| e.name == "tags" }
      expect(tags.schema.type).to eq("array")
      expect(tags.schema.items.type).to eq("string")
      expect(tags.schema.min_items).to eq(1)
      expect(tags.schema.unique_items).to eq(true)
    end

    it "parses $ref references" do
      address = schema.property_entries.find { |e| e.name == "address" }
      expect(address.schema.dollar_ref).to eq("#/definitions/address")
    end

    it "parses definitions" do
      expect(schema.definition_entries.length).to eq(1)
      address_def = schema.definition_entries.find { |e| e.name == "address" }
      expect(address_def.schema.title).to eq("Address")
      expect(address_def.schema.type).to eq("object")
    end

    it "parses nested definition properties" do
      address_def = schema.definition_entries.find { |e| e.name == "address" }
      expect(address_def.schema.property_entries.length).to eq(4)
      zip = address_def.schema.property_entries.find { |e| e.name == "zip" }
      expect(zip.schema.pattern).to eq("[0-9]{5}")
    end

    it "parses nested definition required" do
      address_def = schema.definition_entries.find { |e| e.name == "address" }
      expect(address_def.schema.required).to contain_exactly("street", "city",
                                                             "state", "zip")
    end
  end

  describe ".from_json / #to_json (round-trip)" do
    it "round-trips person.json to equivalent JSON" do
      schema = described_class.from_json(person_json)
      expected = JSON.parse(person_json)
      # definitions → $defs normalization
      expected["$defs"] = expected.delete("definitions")
      # minimum is stored as float (0 → 0.0)
      expected["properties"]["age"]["minimum"] =
        expected["properties"]["age"]["minimum"].to_f

      expect(schema.to_json).to be_json_equivalent_to(JSON.generate(expected))
    end

    it "preserves unknown keywords and x- extensions verbatim" do
      json = JSON.generate({
                             "type" => "object",
                             "x-vendor" => { "deep" => [1, 2] },
                             "futureKeyword" => true,
                             "properties" => {
                               "a" => { "type" => "string", "x-inner" => "keep" },
                             },
                           })
      schema = described_class.from_json(json)

      expect(schema.extensions).to eq(
        "x-vendor" => { "deep" => [1, 2] }, "futureKeyword" => true,
      )
      nested = schema.property_entries.first.schema
      expect(nested.extensions).to eq("x-inner" => "keep")

      round_tripped = JSON.parse(schema.to_json)
      expect(round_tripped).to include(
        "x-vendor" => { "deep" => [1, 2] }, "futureKeyword" => true,
      )
      expect(round_tripped["properties"]["a"]).to include("x-inner" => "keep")
    end

    it "preserves unmodeled keywords across the real-world fixtures" do
      schema = described_class.from_json(
        File.read(File.expand_path("../fixtures/heroku.json", __dir__)),
      )
      feature = schema.definition_entries.find { |e| e.name == "account-feature" }

      # heroku's interagent keywords ("stability", "strictProperties")
      # have no model attribute; they must survive the round trip
      expect(feature.schema.extensions).to include(
        "stability" => "production", "strictProperties" => true,
      )
      round_tripped = JSON.parse(schema.to_json)
      emitted = round_tripped["$defs"]["account-feature"]
      expect(emitted).to include(
        "stability" => "production", "strictProperties" => true,
      )
    end
  end

  describe "simple scalar schema" do
    it "parses a minimal string schema" do
      json = JSON.generate({ "type" => "string", "minLength" => 5 })
      schema = described_class.from_json(json)
      expect(schema.type).to eq("string")
      expect(schema.min_length).to eq(5)
    end
  end

  describe "composition keywords" do
    it "parses allOf" do
      json = JSON.generate({
                             "allOf" => [
                               { "type" => "object",
                                 "properties" => { "a" => { "type" => "string" } } },
                               { "type" => "object",
                                 "properties" => { "b" => { "type" => "integer" } } },
                             ],
                           })
      schema = described_class.from_json(json)
      expect(schema.all_of.length).to eq(2)
      expect(schema.all_property_entries.length).to eq(2)
    end

    it "parses oneOf" do
      json = JSON.generate({
                             "oneOf" => [
                               { "type" => "string" },
                               { "type" => "integer" },
                             ],
                           })
      schema = described_class.from_json(json)
      expect(schema.one_of.length).to eq(2)
    end

    it "parses anyOf" do
      json = JSON.generate({
                             "anyOf" => [
                               { "type" => "string", "format" => "email" },
                               { "type" => "string", "format" => "uri" },
                             ],
                           })
      schema = described_class.from_json(json)
      expect(schema.any_of.length).to eq(2)
      expect(schema.any_of_values.first.format).to eq("email")
    end
  end

  describe "navigation helpers" do
    it "detects object type" do
      schema = described_class.from_json(JSON.generate({ "type" => "object" }))
      expect(schema.object?).to be true
    end

    it "detects array type" do
      schema = described_class.from_json(JSON.generate({ "type" => "array" }))
      expect(schema.array?).to be true
    end

    it "detects $ref" do
      schema = described_class.from_json(JSON.generate({ "$ref" => "#/definitions/foo" }))
      expect(schema.ref?).to be true
    end

    it "collects all_property_entries from allOf" do
      json = JSON.generate({
                             "allOf" => [
                               { "properties" => { "a" => { "type" => "string" } } },
                               { "properties" => { "b" => { "type" => "integer" } } },
                             ],
                           })
      schema = described_class.from_json(json)
      entries = schema.all_property_entries
      expect(entries.map(&:name)).to contain_exactly("a", "b")
    end
  end

  describe "JSON key aliases" do
    it "parses 'id' as dollar_id (draft-03 compatibility)" do
      json = JSON.generate({ "id" => "my-schema" })
      schema = described_class.from_json(json)
      expect(schema.dollar_id).to eq("my-schema")
    end

    it "prefers $id over id when both present" do
      json = '{"$id": "primary", "id": "secondary"}'
      schema = described_class.from_json(json)
      expect(schema.dollar_id).to eq("primary")
    end

    it "serializes dollar_id as $id (not id)" do
      json = JSON.generate({ "id" => "from-id" })
      schema = described_class.from_json(json)
      output = JSON.parse(schema.to_json)
      expect(output).to have_key("$id")
      expect(output["$id"]).to eq("from-id")
      expect(output).not_to have_key("id")
    end

    it "parses 'example' as examples" do
      json = JSON.generate({ "example" => "hello" })
      schema = described_class.from_json(json)
      expect(schema.examples).to include("hello")
    end

    it "parses '$defs' as definition_entries" do
      json = JSON.generate({
                             "$defs" => {
                               "email" => { "type" => "string",
                                            "format" => "email" },
                             },
                           })
      schema = described_class.from_json(json)
      expect(schema.definition_entries.length).to eq(1)
      expect(schema.definition_entries.first.name).to eq("email")
      expect(schema.definition_entries.first.schema.format).to eq("email")
    end

    it "round-trips $defs preserving $defs key" do
      expected = JSON.generate({
                                 "$defs" => {
                                   "email" => { "type" => "string",
                                                "format" => "email" },
                                 },
                               })
      schema = described_class.from_json(expected)
      expect(schema.to_json).to be_json_equivalent_to(expected)
    end

    it "normalizes definitions to $defs on output" do
      input = JSON.generate({
                              "definitions" => {
                                "email" => { "type" => "string",
                                             "format" => "email" },
                              },
                            })
      expected = JSON.generate({
                                 "$defs" => {
                                   "email" => { "type" => "string",
                                                "format" => "email" },
                                 },
                               })
      schema = described_class.from_json(input)
      expect(schema.to_json).to be_json_equivalent_to(expected)
    end
  end

  describe "additionalProperties as schema" do
    it "parses additionalProperties as schema object" do
      json = JSON.generate({
                             "type" => "object",
                             "additionalProperties" => { "type" => "string" },
                           })
      schema = described_class.from_json(json)
      expect(schema.additional_properties_schema).to be_a(described_class)
      expect(schema.additional_properties_schema.type).to eq("string")
      expect(schema.additional_properties).to be_nil
    end

    it "round-trips additionalProperties schema" do
      json = JSON.generate({
                             "type" => "object",
                             "additionalProperties" => { "type" => "integer" },
                           })
      schema = described_class.from_json(json)
      output = JSON.parse(schema.to_json)
      expect(output["additionalProperties"]["type"]).to eq("integer")
    end
  end
end

RSpec.describe Lutaml::Jsonschema::PropertyEntry do
  let(:schema) do
    Lutaml::Jsonschema::Schema.from_json(JSON.generate({
                                                         "type" => "object",
                                                         "properties" => {
                                                           "name" => { "type" => "string" },
                                                           "count" => {
                                                             "type" => "integer", "minimum" => 0
                                                           },
                                                         },
                                                       }))
  end

  it "creates PropertyEntry for each property" do
    expect(schema.property_entries.length).to eq(2)
    names = schema.property_entries.map(&:name)
    expect(names).to contain_exactly("name", "count")
  end

  it "wraps each property in a Schema" do
    entry = schema.property_entries.find { |e| e.name == "count" }
    expect(entry.schema.type).to eq("integer")
    expect(entry.schema.minimum).to eq(0.0)
  end

  it "preserves name and schema through JSON serialization" do
    entry = schema.property_entries.find { |e| e.name == "name" }
    parsed = JSON.parse(entry.to_json)
    expect(parsed["name"]).to eq("name")
    expect(parsed["schema"]["type"]).to eq("string")
  end
end

RSpec.describe Lutaml::Jsonschema::Link do
  it "parses a hyper-schema link" do
    json = JSON.generate({
                           "href" => "/users",
                           "method" => "POST",
                           "rel" => "create",
                           "title" => "Create User",
                           "description" => "Create a new user",
                           "schema" => { "type" => "object",
                                         "properties" => { "name" => { "type" => "string" } } },
                           "targetSchema" => { "type" => "object",
                                               "properties" => { "id" => { "type" => "string" } } },
                         })
    link = described_class.from_json(json)
    expect(link.href).to eq("/users")
    expect(link.http_method).to eq("POST")
    expect(link.rel).to eq("create")
    expect(link.schema.type).to eq("object")
    expect(link.target_schema.property_entries.length).to eq(1)
  end
end

RSpec.describe Lutaml::Jsonschema::ReferenceResolver do
  let(:schema) { Lutaml::Jsonschema::Schema.from_json(File.read(File.join(__dir__, "..", "fixtures", "person.json"))) }
  let(:resolver) { described_class.new }

  describe "#resolve" do
    it "resolves a local $ref to a definition" do
      address = schema.property_entries.find { |e| e.name == "address" }
      resolved = resolver.resolve(address.schema.dollar_ref, schema)
      expect(resolved).not_to be_nil
      expect(resolved.title).to eq("Address")
    end

    it "returns nil for unresolvable refs" do
      expect(resolver.resolve("#/definitions/nonexistent", schema)).to be_nil
    end

    it "returns nil for nil ref" do
      expect(resolver.resolve(nil, schema)).to be_nil
    end

    it "resolves nested paths" do
      resolved = resolver.resolve("#/definitions/address/properties/zip",
                                  schema)
      expect(resolved).not_to be_nil
      expect(resolved.pattern).to eq("[0-9]{5}")
    end
  end
end

RSpec.describe Lutaml::Jsonschema::SchemaSet do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }

  describe ".load_from_files" do
    it "loads multiple schema files" do
      set = described_class.load_from_files(
        File.join(fixtures_dir, "person.json"),
        File.join(fixtures_dir, "user.json"),
      )
      expect(set.schemas.length).to eq(2)
      expect(set.schemas["person"].title).to eq("Person")
      expect(set.schemas["user"].title).to eq("User")
    end
  end

  describe "#all_definitions" do
    it "collects definitions from all schemas" do
      set = described_class.load_from_files(
        File.join(fixtures_dir, "person.json"),
        File.join(fixtures_dir, "user.json"),
      )
      defs = set.all_definitions
      expect(defs.length).to eq(1)
      expect(defs.first.name).to eq("address")
    end
  end

  describe "#all_properties" do
    it "collects properties from all schemas" do
      set = described_class.load_from_files(
        File.join(fixtures_dir, "person.json"),
        File.join(fixtures_dir, "user.json"),
      )
      props = set.all_properties
      expect(props.length).to eq(9) # 6 from person + 3 from user
    end
  end
end

RSpec.describe Lutaml::Jsonschema::Combiner do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }
  let(:schema_set) do
    Lutaml::Jsonschema::SchemaSet.load_from_files(
      File.join(fixtures_dir, "person.json"),
      File.join(fixtures_dir, "user.json"),
    )
  end

  it "combines schemas into a single schema" do
    combined = described_class.new.combine(schema_set)
    expect(combined.title).to eq("Person")
    expect(combined.property_entries.length).to eq(2)
    names = combined.property_entries.map(&:name)
    expect(names).to contain_exactly("person", "user")
  end

  it "merges definitions into the combined schema" do
    combined = described_class.new.combine(schema_set)
    expect(combined.definition_entries.length).to eq(1)
    expect(combined.definition_entries.first.name).to eq("address")
  end

  it "creates $ref entries for each schema" do
    combined = described_class.new.combine(schema_set)
    person_ref = combined.property_entries.find { |e| e.name == "person" }
    expect(person_ref.schema.dollar_ref).to eq("#/$defs/person")
  end

  it "round-trips combined schema to JSON" do
    combined = described_class.new.combine(schema_set)
    address_def = JSON.parse(File.read(File.join(fixtures_dir,
                                                 "person.json")))["definitions"]["address"]
    expected = JSON.generate({
                               "title" => "Person",
                               "properties" => {
                                 "person" => { "$ref" => "#/$defs/person" },
                                 "user" => { "$ref" => "#/$defs/user" },
                               },
                               "$defs" => { "address" => address_def },
                             })
    expect(combined.to_json).to be_json_equivalent_to(expected)
  end
end
