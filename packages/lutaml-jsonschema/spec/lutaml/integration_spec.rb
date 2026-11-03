# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"

RSpec.describe "Integration: Reference fixture schemas" do
  let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }

  def load_fixture(name)
    path = File.join(fixtures_dir, name)
    data = File.read(path)
    [data, JSON.parse(data)]
  end

  # --- prmd user.json ---

  describe "prmd user fixture" do
    let(:json_data) { load_fixture("prmd_user.json") }
    let(:raw) { json_data[1] }
    let(:schema) { Lutaml::Jsonschema::Schema.from_json(json_data[0]) }

    it "parses title and description" do
      expect(schema.title).to eq("API - User")
      expect(schema.description).to eq("User represents an API account.")
    end

    it "parses type as array" do
      expect(schema.types).to eq(["object"])
    end

    it "parses $schema and $id" do
      expect(schema.dollar_schema).to eq("http://json-schema.org/draft-04/hyper-schema")
      expect(schema.dollar_id).to eq("schemata/user")
    end

    it "parses definitions with nested sub-definitions" do
      defs = schema.definition_entries
      expect(defs.map(&:name)).to include("created_at", "id", "identity",
                                          "updated_at")

      id_def = defs.find { |d| d.name == "id" }
      expect(id_def.schema.description).to eq("unique identifier of user")
      expect(id_def.schema.format).to eq("uuid")
      expect(id_def.schema.types).to eq(["string"])
    end

    it "parses $ref within definitions" do
      identity = schema.definition_entries.find { |d| d.name == "identity" }
      expect(identity.schema.dollar_ref).to eq("/schemata/user#/definitions/id")
    end

    it "parses hyper-schema links" do
      expect(schema.links.length).to eq(5)

      create_link = schema.links.find { |l| l.rel == "create" }
      expect(create_link.http_method).to eq("POST")
      expect(create_link.href).to eq("/users")
      expect(create_link.title).to eq("Create")
      expect(create_link.description).to eq("Create a new user.")

      # Link with request body schema
      expect(create_link.schema).to be_a(Lutaml::Jsonschema::Schema)
      expect(create_link.schema.types).to eq(["object"])

      # Nested properties within link schema
      user_prop = create_link.schema.property_entries.find do |p|
        p.name == "user"
      end
      expect(user_prop).not_to be_nil
      expect(user_prop.schema.types).to eq(["object"])
      expect(user_prop.schema.required).to eq(["email"])
    end

    it "parses properties with $ref" do
      props = schema.property_entries
      expect(props.map(&:name)).to contain_exactly("created_at", "id",
                                                   "updated_at")

      created_at = props.find { |p| p.name == "created_at" }
      expect(created_at.schema.dollar_ref).to eq("/schemata/user#/definitions/created_at")
    end

    it "parses example fields" do
      id_def = schema.definition_entries.find { |d| d.name == "id" }
      expect(id_def.schema.examples).to include("01234567-89ab-cdef-0123-456789abcdef")
    end

    it "round-trips to semantically equivalent JSON" do
      output = schema.to_json
      reparsed = Lutaml::Jsonschema::Schema.from_json(output).to_json
      expect(reparsed).to be_json_equivalent_to(output)
    end
  end

  # --- interagent simple.json (json-schema-docs fixture) ---

  describe "interagent simple fixture" do
    let(:json_data) { load_fixture("interagent_simple.json") }
    let(:raw) { json_data[1] }
    let(:schema) { Lutaml::Jsonschema::Schema.from_json(json_data[0]) }

    it "parses the combined multi-entity schema" do
      expect(schema.title).to eq("Rake Task Test")
      expect(schema.types).to eq(["object"])
    end

    it "parses nested definitions (post and user entities)" do
      defs = schema.definition_entries
      expect(defs.map(&:name)).to contain_exactly("post", "user")

      post_def = defs.find { |d| d.name == "post" }
      expect(post_def.schema.title).to eq("Post")
      expect(post_def.schema.links.length).to eq(5)
    end

    it "parses link with targetSchema" do
      post_def = schema.definition_entries.find { |d| d.name == "post" }
      info_link = post_def.schema.links.find { |l| l.rel == "self" }
      expect(info_link.target_schema).to be_a(Lutaml::Jsonschema::Schema)
      expect(info_link.target_schema.dollar_ref).to eq("#/definitions/post")
    end

    it "parses deeply nested definitions" do
      post_def = schema.definition_entries.find { |d| d.name == "post" }
      inner_defs = post_def.schema.definition_entries
      expect(inner_defs.map(&:name)).to include("id", "identity", "created_at",
                                                "updated_at")
    end

    it "parses top-level links" do
      expect(schema.links.length).to eq(1)
      expect(schema.links.first.rel).to eq("self")
      expect(schema.links.first.href).to eq("https://prmd.rake_task_test.io")
    end

    it "round-trips definitions structure" do
      output = schema.to_json
      reparsed = Lutaml::Jsonschema::Schema.from_json(output).to_json
      expect(reparsed).to be_json_equivalent_to(output)
    end
  end

  # --- Comprehensive fixture ---

  describe "comprehensive fixture (all major keywords)" do
    let(:json_data) { load_fixture("comprehensive.json") }
    let(:raw) { json_data[1] }
    let(:schema) { Lutaml::Jsonschema::Schema.from_json(json_data[0]) }

    it "parses $comment" do
      expect(schema.dollar_comment).to include("comprehensive schema")
    end

    it "parses enum property" do
      status = schema.property_entries.find { |p| p.name == "status" }
      expect(status.schema.enum).to eq(%w[active inactive pending archived])
    end

    it "parses default value" do
      status = schema.property_entries.find { |p| p.name == "status" }
      expect(status.schema.default).to eq("pending")
    end

    it "parses numeric constraints" do
      priority = schema.property_entries.find { |p| p.name == "priority" }
      expect(priority.schema.minimum).to eq(1)
      expect(priority.schema.maximum).to eq(10)
      expect(priority.schema.exclusive_minimum).to eq(0)
      expect(priority.schema.multiple_of).to eq(1)

      score = schema.property_entries.find { |p| p.name == "score" }
      expect(score.schema.exclusive_minimum).to eq(0.0)
      expect(score.schema.exclusive_maximum).to eq(100.0)
    end

    it "parses array constraints" do
      schema.property_entries.find { |p| p.name == "tags" }
        &.schema&.items
      # tags is inside metadata, but let's check the path
      # Actually metadata.tags needs nested traversal
      metadata = schema.property_entries.find { |p| p.name == "metadata" }
      tags_prop = metadata.schema.property_entries.find { |p| p.name == "tags" }
      expect(tags_prop.schema.min_items).to eq(1)
      expect(tags_prop.schema.max_items).to eq(10)
      expect(tags_prop.schema.unique_items).to eq(true)
      expect(tags_prop.schema.items).to be_a(Lutaml::Jsonschema::Schema)
      expect(tags_prop.schema.items.types).to eq(["string"])
    end

    it "parses const" do
      metadata = schema.property_entries.find { |p| p.name == "metadata" }
      label = metadata.schema.property_entries.find { |p| p.name == "label" }
      expect(label.schema.const).to eq("special")
    end

    it "parses allOf" do
      contact = schema.property_entries.find { |p| p.name == "contact" }
      expect(contact.schema.all_of.length).to eq(2)
      # First element is a $ref
      expect(contact.schema.all_of_values[0].dollar_ref).to eq("#/$defs/email")
      # Second element has its own properties
      expect(contact.schema.all_of_values[1].property_entries.map(&:name)).to include("phone")
    end

    it "parses anyOf" do
      alt = schema.property_entries.find { |p| p.name == "alternative_contact" }
      expect(alt.schema.any_of.length).to eq(2)
      expect(alt.schema.any_of_values[0].dollar_ref).to eq("#/$defs/email")
      expect(alt.schema.any_of_values[1].dollar_ref).to eq("#/$defs/phone")
    end

    it "parses oneOf" do
      shipping = schema.property_entries.find { |p| p.name == "shipping" }
      expect(shipping.schema.one_of.length).to eq(2)
      expect(shipping.schema.one_of_values[0].property_entries.find do |p|
        p.name == "method"
      end
                                     &.schema&.const).to eq("standard")
      expect(shipping.schema.one_of_values[1].property_entries.find do |p|
        p.name == "method"
      end
                                     &.schema&.const).to eq("express")
    end

    it "parses patternProperties" do
      tags_map = schema.property_entries.find { |p| p.name == "tags_map" }
      expect(tags_map.schema.pattern_property_entries.length).to eq(2)
      patterns = tags_map.schema.pattern_property_entries.map(&:name)
      expect(patterns).to include("^x-", "^[a-z]+$")
    end

    it "parses additionalProperties as boolean" do
      tags_map = schema.property_entries.find { |p| p.name == "tags_map" }
      expect(tags_map.schema.additional_properties).to be_falsey
    end

    it "parses minProperties / maxProperties" do
      tags_map = schema.property_entries.find { |p| p.name == "tags_map" }
      expect(tags_map.schema.min_properties).to eq(1)
      expect(tags_map.schema.max_properties).to eq(20)
    end

    it "parses not" do
      not_str = schema.property_entries.find { |p| p.name == "not_a_string" }
      expect(not_str.schema.not_schema).to be_a(Lutaml::Jsonschema::Schema)
      expect(not_str.schema.not_schema.types).to eq(["string"])
    end

    it "parses deprecated and readOnly" do
      dep = schema.property_entries.find { |p| p.name == "deprecated_field" }
      expect(dep.schema.deprecated).to eq(true)
      expect(dep.schema.read_only).to eq(true)
    end

    it "parses writeOnly" do
      wo = schema.property_entries.find { |p| p.name == "write_only_field" }
      expect(wo.schema.write_only).to eq(true)
    end

    it "parses type as array (nullable)" do
      nullable = schema.property_entries.find { |p| p.name == "nullable_field" }
      expect(nullable.schema.types).to contain_exactly("string", "null")
    end

    it "parses contains" do
      contained = schema.property_entries.find do |p|
        p.name == "contained_array"
      end
      expect(contained.schema.contains).to be_a(Lutaml::Jsonschema::Schema)
      expect(contained.schema.contains.types).to eq(["integer"])
    end

    it "parses $defs" do
      defs = schema.definition_entries
      def_names = defs.map(&:name)
      expect(def_names).to include("email", "phone", "address", "legacy_def")
    end

    it "parses if/then/else" do
      expect(schema.if_schema).to be_a(Lutaml::Jsonschema::Schema)
      expect(schema.then_schema).to be_a(Lutaml::Jsonschema::Schema)
      expect(schema.else_schema).to be_a(Lutaml::Jsonschema::Schema)

      expect(schema.if_schema.property_entries.first.name).to eq("status")
      expect(schema.then_schema.required).to eq(%w[priority contact])
    end

    it "round-trips to semantically equivalent JSON" do
      output = schema.to_json
      reparsed = Lutaml::Jsonschema::Schema.from_json(output).to_json
      expect(reparsed).to be_json_equivalent_to(output)
    end
  end

  # --- Heroku API fixture ---

  describe "Heroku Platform API fixture (large real-world schema)" do
    let(:json_data) { load_fixture("heroku.json") }
    let(:raw) { json_data[1] }
    let(:schema) { Lutaml::Jsonschema::Schema.from_json(json_data[0]) }

    it "parses without errors" do
      expect(schema).to be_a(Lutaml::Jsonschema::Schema)
    end

    it "parses dozens of entity definitions" do
      defs = schema.definition_entries
      expect(defs.length).to be > 10
      names = defs.map(&:name)
      expect(names).to include("account-feature", "add-on-attachment", "app", "dyno", "formation",
                               "oauth-authorization", "region")
    end

    it "parses links in definitions with schema and targetSchema" do
      app_def = schema.definition_entries.find { |d| d.name == "app" }
      expect(app_def).not_to be_nil
      expect(app_def.schema.links.length).to be > 0

      create_link = app_def.schema.links.find { |l| l.rel == "create" }
      expect(create_link).not_to be_nil
      expect(create_link.http_method).to eq("POST")
      expect(create_link.schema).to be_a(Lutaml::Jsonschema::Schema)
    end

    it "parses anyOf in identity definitions" do
      # Heroku uses anyOf for identity (accept either id or name)
      account_feature = schema.definition_entries.find do |d|
        d.name == "account-feature"
      end
      identity = account_feature.schema.definition_entries.find do |d|
        d.name == "identity"
      end
      expect(identity.schema.any_of.length).to eq(2)
    end

    it "parses readOnly fields" do
      account_feature = schema.definition_entries.find do |d|
        d.name == "account-feature"
      end
      created_at = account_feature.schema.definition_entries.find do |d|
        d.name == "created_at"
      end
      expect(created_at.schema.read_only).to eq(true)
    end

    it "round-trips definition count" do
      output = schema.to_json
      reparsed = Lutaml::Jsonschema::Schema.from_json(output).to_json
      expect(reparsed).to be_json_equivalent_to(output)
    end
  end

  # --- SchemaSet with reference fixtures ---

  describe "SchemaSet with prmd + interagent fixtures" do
    let(:schema_set) do
      Lutaml::Jsonschema::SchemaSet.load_from_files(
        File.join(fixtures_dir, "prmd_user.json"),
        File.join(fixtures_dir, "interagent_simple.json"),
      )
    end

    it "loads both schemas" do
      expect(schema_set.schemas.keys).to contain_exactly("prmd_user",
                                                         "interagent_simple")
    end

    it "collects all definitions across schemas" do
      defs = schema_set.all_definitions
      names = defs.map(&:name)
      expect(names).to include("post", "user", "created_at", "id", "identity",
                               "updated_at")
    end

    it "resolves local references" do
      interagent = schema_set.schemas["interagent_simple"]
      # properties.post has $ref: "#/definitions/post"
      post_ref = interagent.property_entries.find do |p|
        p.name == "post"
      end.schema.dollar_ref
      result = schema_set.resolve_ref(post_ref, interagent)
      expect(result).not_to be_nil
      expect(result.title).to eq("Post")
    end
  end

  # --- SPA generation with real fixtures ---

  describe "SPA generation with interagent fixture" do
    it "generates HTML with all entities" do
      Dir.mktmpdir do |dir|
        set = Lutaml::Jsonschema::SchemaSet.load_from_files(
          File.join(fixtures_dir, "interagent_simple.json"),
        )
        metadata = Lutaml::Jsonschema::Spa::Metadata.new(
          title: "Interagent API", theme: "dark",
        )
        generator = Lutaml::Jsonschema::Spa::Generator.new(set, dir,
                                                           metadata: metadata)
        generator.generate

        html = File.read(File.join(dir, "index.html"))
        expect(html).to include("window.SCHEMA_DATA")
        expect(html).to include("Interagent API")

        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])
        expect(data["metadata"]["theme"]).to eq("dark")
        expect(data["schemas"].length).to be >= 1

        # Verify schema data has definitions
        schema_data = data["schemas"].first
        expect(schema_data["name"]).to eq("interagent_simple")
        expect(schema_data["definitions"].length).to be > 0
      end
    end
  end
end
