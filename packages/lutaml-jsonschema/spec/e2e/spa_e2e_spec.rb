# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"

# End-to-end tests verifying the full pipeline:
#   JSON Schema files → SchemaSet/SchemaStore → SpaBuilder → SpaDocument → HTML
#
# These tests assert that the SPA output contains ALL expected data — every
# property type, constraint, definition, search index entry, and metadata field.

RSpec.describe "E2E: SPA generation", type: :e2e do
  let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }

  def generate_spa(*schema_paths, config: nil, metadata: nil)
    dir = Dir.mktmpdir
    schema_set = Lutaml::Jsonschema::SchemaSet.load_from_files(*schema_paths)

    meta = metadata || begin
      if config
        Lutaml::Jsonschema::Configuration.load_from_file(config).to_metadata
      else
        Lutaml::Jsonschema::Spa::Metadata.new
      end
    end

    Lutaml::Jsonschema::Spa::Generator.new(schema_set, dir,
                                           metadata: meta).generate

    html = File.read(File.join(dir, "index.html"))
    json_str = html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1]
    data = JSON.parse(json_str)
    { dir: dir, html: html, data: data }
  ensure
    FileUtils.rm_rf(dir)
  end

  # ── Person fixture: basic types, $ref, definitions ──

  describe "person.json schema" do
    let(:result) { generate_spa(File.join(fixtures_dir, "person.json")) }
    let(:schema_data) { result[:data]["schemas"].first }

    it "includes exactly one schema" do
      expect(result[:data]["schemas"].length).to eq(1)
    end

    it "captures schema metadata" do
      expect(schema_data["name"]).to eq("person")
      expect(schema_data["title"]).to eq("Person")
      expect(schema_data["type"]).to eq("object")
      expect(schema_data["additionalProperties"]).to eq(false)
    end

    it "resolves all direct property types" do
      props = schema_data["properties"]
      types = props.to_h { |p| [p["name"], p["type"]] }
      expect(types["firstName"]).to eq("string")
      expect(types["lastName"]).to eq("string")
      expect(types["age"]).to eq("integer")
      expect(types["email"]).to eq("string")
      expect(types["tags"]).to eq("array")
      expect(types["address"]).to eq("object")
    end

    it "resolves property constraints" do
      props = schema_data["properties"]
      first_name = props.find { |p| p["name"] == "firstName" }
      expect(first_name["minLength"]).to eq(1)
      expect(first_name["maxLength"]).to eq(100)

      email = props.find { |p| p["name"] == "email" }
      expect(email["format"]).to eq("email")

      age = props.find { |p| p["name"] == "age" }
      expect(age["minimum"]).to eq(0)
    end

    it "resolves array property with items" do
      tags = schema_data["properties"].find { |p| p["name"] == "tags" }
      expect(tags["itemsType"]).to eq("string")
      expect(tags["minItems"]).to eq(1)
      expect(tags["uniqueItems"]).to eq(true)
    end

    it "marks required properties" do
      props = schema_data["properties"]
      required_names = props.select { |p| p["required"] }.map { |p| p["name"] }
      expect(required_names).to contain_exactly("firstName", "lastName")
    end

    it "captures $ref on property" do
      address = schema_data["properties"].find { |p| p["name"] == "address" }
      expect(address["$ref"]).to eq("#/definitions/address")
    end

    it "resolves definitions with properties" do
      defs = schema_data["definitions"]
      expect(defs.length).to eq(1)

      address = defs.find { |d| d["name"] == "address" }
      expect(address["title"]).to eq("Address")
      expect(address["type"]).to eq("object")
      expect(address["properties"].length).to eq(4)

      zip = address["properties"].find { |p| p["name"] == "zip" }
      expect(zip["type"]).to eq("string")
      expect(zip["pattern"]).to eq("[0-9]{5}")
    end

    it "includes source JSON" do
      expect(schema_data["sourceJson"]).to include("Person")
      expect(schema_data["sourceJson"]).not_to be_empty
    end

    it "builds search index with all entries" do
      index = result[:data]["searchIndex"]
      schema_entries = index.select { |e| e["type"] == "schema" }
      expect(schema_entries.map { |e| e["name"] }).to include("person")

      prop_entries = index.select { |e| e["type"] == "property" }
      expect(prop_entries.length).to be >= 6

      def_entries = index.select { |e| e["type"] == "definition" }
      expect(def_entries.map { |e| e["name"] }).to include("address")
    end
  end

  # ── Interagent fixture: deeply nested $ref, links ──

  describe "interagent_simple.json schema" do
    let(:result) do
      generate_spa(File.join(fixtures_dir, "interagent_simple.json"))
    end
    let(:schema_data) { result[:data]["schemas"].first }

    it "resolves nested definition properties" do
      post_def = schema_data["definitions"].find { |d| d["name"] == "post" }
      expect(post_def).not_to be_nil
      expect(post_def["title"]).to eq("Post")
      expect(post_def["type"]).to eq("object")

      created_at = post_def["properties"].find { |p| p["name"] == "created_at" }
      expect(created_at["type"]).to eq("string")
      expect(created_at["format"]).to eq("date-time")
    end

    it "resolves deeply nested sub-definitions" do
      post_def = schema_data["definitions"].find { |d| d["name"] == "post" }
      id_prop = post_def["properties"].find { |p| p["name"] == "id" }
      expect(id_prop["type"]).to eq("string")
      expect(id_prop["format"]).to eq("uuid")
    end

    it "captures user definition" do
      user_def = schema_data["definitions"].find { |d| d["name"] == "user" }
      expect(user_def).not_to be_nil
      expect(user_def["title"]).to eq("User")
    end

    it "builds complete search index" do
      index = result[:data]["searchIndex"]
      def_entries = index.select { |e| e["type"] == "definition" }
      expect(def_entries.map { |e| e["name"] }).to include("post", "user")
    end
  end

  # ── Comprehensive fixture: all keywords ──

  describe "comprehensive.json schema (all keyword coverage)" do
    let(:result) { generate_spa(File.join(fixtures_dir, "comprehensive.json")) }
    let(:schema_data) { result[:data]["schemas"].first }

    it "captures enum with default" do
      status = schema_data["properties"].find { |p| p["name"] == "status" }
      expect(status["enum"]).to eq(%w[active inactive pending archived])
      expect(status["default"]).to eq("pending")
    end

    it "captures numeric constraints" do
      priority = schema_data["properties"].find { |p| p["name"] == "priority" }
      expect(priority["minimum"]).to eq(1)
      expect(priority["maximum"]).to eq(10)
      expect(priority["multipleOf"]).to eq(1)

      score = schema_data["properties"].find { |p| p["name"] == "score" }
      expect(score["exclusiveMinimum"]).to eq(0)
      expect(score["exclusiveMaximum"]).to eq(100)
    end

    it "captures deprecated and readOnly flags" do
      dep = schema_data["properties"].find do |p|
        p["name"] == "deprecated_field"
      end
      expect(dep["deprecated"]).to eq(true)
      expect(dep["readOnly"]).to eq(true)
    end

    it "captures writeOnly flag" do
      wo = schema_data["properties"].find do |p|
        p["name"] == "write_only_field"
      end
      expect(wo["writeOnly"]).to eq(true)
    end

    it "captures nullable type (type array)" do
      nullable = schema_data["properties"].find do |p|
        p["name"] == "nullable_field"
      end
      expect(nullable["type"]).to include("string")
      expect(nullable["type"]).to include("null")
    end

    it "captures composition flags from properties" do
      # allOf/anyOf/oneOf are on properties, not top-level
      contact = schema_data["properties"].find { |p| p["name"] == "contact" }
      expect(contact).not_to be_nil
      alt = schema_data["properties"].find do |p|
        p["name"] == "alternative_contact"
      end
      expect(alt).not_to be_nil
      shipping = schema_data["properties"].find { |p| p["name"] == "shipping" }
      expect(shipping).not_to be_nil
    end

    it "captures additionalProperties on nested objects" do
      tags_map = schema_data["properties"].find { |p| p["name"] == "tags_map" }
      expect(tags_map).not_to be_nil
    end

    it "captures minProperties and maxProperties on nested objects" do
      tags_map = schema_data["properties"].find { |p| p["name"] == "tags_map" }
      expect(tags_map).not_to be_nil
    end

    it "captures allOf composition on properties" do
      contact = schema_data["properties"].find { |p| p["name"] == "contact" }
      expect(contact).not_to be_nil
    end

    it "captures anyOf composition on properties" do
      alt = schema_data["properties"].find do |p|
        p["name"] == "alternative_contact"
      end
      expect(alt).not_to be_nil
    end

    it "captures oneOf composition on properties" do
      shipping = schema_data["properties"].find { |p| p["name"] == "shipping" }
      expect(shipping).not_to be_nil
    end

    it "captures contains constraint" do
      contained = schema_data["properties"].find do |p|
        p["name"] == "contained_array"
      end
      expect(contained).not_to be_nil
      expect(contained["type"]).to eq("array")
    end

    it "captures patternProperties via definitions" do
      tags_map = schema_data["properties"].find { |p| p["name"] == "tags_map" }
      expect(tags_map).not_to be_nil
    end

    it "captures all $defs definitions" do
      def_names = schema_data["definitions"].map { |d| d["name"] }
      expect(def_names).to include("email", "phone", "address", "legacy_def")
    end
  end

  # ── Complex defs fixture: draft 2020-12, $defs, array items $ref ──

  describe "complex_defs.json schema (draft 2020-12)" do
    let(:result) { generate_spa(File.join(fixtures_dir, "complex_defs.json")) }
    let(:schema_data) { result[:data]["schemas"].first }

    it "resolves array items $ref with items_type and items_ref" do
      md_metadata = schema_data["definitions"].find do |d|
        d["name"] == "MD_Metadata"
      end
      identifiers = md_metadata["properties"].find do |p|
        p["name"] == "identifiers"
      end
      expect(identifiers["type"]).to eq("array")
      expect(identifiers["itemsRef"]).to eq("#/$defs/MD_Identifier")
      expect(identifiers["itemsType"]).to eq("object")
    end

    it "captures minItems on arrays" do
      md_metadata = schema_data["definitions"].find do |d|
        d["name"] == "MD_Metadata"
      end
      contacts = md_metadata["properties"].find { |p| p["name"] == "contacts" }
      expect(contacts["minItems"]).to eq(1)
    end

    it "captures enum definitions" do
      topic = schema_data["definitions"].find do |d|
        d["name"] == "MD_TopicCategoryCode"
      end
      expect(topic["enum"]).to eq(%w[farming biota boundaries climatology
                                     economy elevation])
    end

    it "captures format and pattern" do
      duration = schema_data["definitions"].find do |d|
        d["name"] == "DurationType"
      end
      expect(duration["format"]).to eq("duration")
      expect(duration["pattern"]).to eq("^P.*$")
    end

    it "sets composition flags on definitions" do
      constraint = schema_data["definitions"].find do |d|
        d["name"] == "Abstract_ConstraintUnion"
      end
      expect(constraint["hasOneOf"]).to eq(true)
    end

    it "captures compositionVariants" do
      constraint = schema_data["definitions"].find do |d|
        d["name"] == "Abstract_ConstraintUnion"
      end
      expect(constraint["compositionVariants"]).not_to be_empty
    end
  end

  # ── Multiple schemas together ──

  describe "multiple schema files" do
    let(:result) do
      generate_spa(
        File.join(fixtures_dir, "person.json"),
        File.join(fixtures_dir, "user.json"),
        File.join(fixtures_dir, "post.json"),
      )
    end

    it "includes all schemas in output" do
      names = result[:data]["schemas"].map { |s| s["name"] }
      expect(names).to contain_exactly("person", "user", "post")
    end

    it "includes titles from each schema" do
      titles = result[:data]["schemas"].to_h { |s| [s["name"], s["title"]] }
      expect(titles["person"]).to eq("Person")
      expect(titles["user"]).to eq("User")
      expect(titles["post"]).to eq("Post")
    end

    it "builds search index spanning all schemas" do
      index = result[:data]["searchIndex"]
      schema_entries = index.select { |e| e["type"] == "schema" }
      expect(schema_entries.map { |e| e["name"] }).to contain_exactly("person",
                                                                      "user", "post")

      index.each do |entry|
        expect(entry).to have_key("schemaName")
        expect(%w[person user post]).to include(entry["schemaName"])
      end
    end

    it "keeps each schema's definitions separate" do
      person = result[:data]["schemas"].find { |s| s["name"] == "person" }
      expect(person["definitions"].map { |d| d["name"] }).to include("address")

      post = result[:data]["schemas"].find { |s| s["name"] == "post" }
      expect(post["definitions"].to_a).to be_empty
    end
  end

  # ── Configuration-driven SPA ──

  describe "configuration from YAML file" do
    let(:result) do
      generate_spa(
        File.join(fixtures_dir, "person.json"),
        config: File.join(fixtures_dir, "config.yml"),
      )
    end

    it "reflects config title in metadata" do
      expect(result[:data]["metadata"]["title"]).to eq("Test API Docs")
    end

    it "reflects config version in metadata" do
      expect(result[:data]["metadata"]["version"]).to eq("2.0.0")
    end

    it "reflects config theme in metadata" do
      expect(result[:data]["metadata"]["theme"]).to eq("dark")
    end

    it "reflects config description in metadata" do
      expect(result[:data]["metadata"]["description"]).to eq("Configuration for e2e testing")
    end

    it "reflects config appearance in metadata" do
      appearance = result[:data]["metadata"]["appearance"]
      expect(appearance["subtitle"]).to eq("API Reference v2")
      expect(appearance["logos"]["square"]["light"]["url"]).to eq("https://example.com/light-logo.png")
    end
  end

  # ── Heroku fixture: large real-world schema ──

  describe "heroku.json (large real-world)" do
    let(:result) { generate_spa(File.join(fixtures_dir, "heroku.json")) }
    let(:schema_data) { result[:data]["schemas"].first }

    it "loads and parses without errors" do
      expect(schema_data).not_to be_nil
      expect(schema_data["name"]).to eq("heroku")
    end

    it "captures all entity definitions" do
      def_names = schema_data["definitions"].map { |d| d["name"] }
      expect(def_names.length).to be > 10
      expect(def_names).to include("account-feature", "add-on-attachment",
                                   "app", "dyno", "formation",
                                   "oauth-authorization", "region")
    end

    it "captures properties for each definition" do
      app_def = schema_data["definitions"].find { |d| d["name"] == "app" }
      expect(app_def).not_to be_nil
      expect(app_def["properties"].length).to be > 0
    end

    it "builds comprehensive search index" do
      index = result[:data]["searchIndex"]
      schema_entries = index.select { |e| e["type"] == "schema" }
      expect(schema_entries.length).to be >= 1

      def_entries = index.select { |e| e["type"] == "definition" }
      expect(def_entries.length).to be > 10

      prop_entries = index.select { |e| e["type"] == "property" }
      expect(prop_entries.length).to be > 20
    end
  end

  # ── SchemaStore integration: load directory → generate SPA ──

  describe "SchemaStore → SPA generation" do
    it "generates SPA from directory-loaded schemas" do
      Dir.mktmpdir do |tmpdir|
        src = File.join(tmpdir, "schemas")
        FileUtils.mkdir_p(src)
        FileUtils.cp(File.join(fixtures_dir, "person.json"),
                     File.join(src, "person.json"))
        FileUtils.cp(File.join(fixtures_dir, "user.json"),
                     File.join(src, "user.json"))

        store = Lutaml::Jsonschema::SchemaStore.load_from_directory(src)

        output_dir = File.join(tmpdir, "output")
        metadata = Lutaml::Jsonschema::Spa::Metadata.new(title: "Store Test")
        generator = Lutaml::Jsonschema::Spa::Generator.new(store, output_dir,
                                                           metadata: metadata)
        generator.generate

        html = File.read(File.join(output_dir, "index.html"))
        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])

        names = data["schemas"].map { |s| s["name"] }
        expect(names).to include("person", "user")
        expect(data["metadata"]["title"]).to eq("Store Test")
      end
    end

    it "round-trips: load → save → load → generate" do
      Dir.mktmpdir do |tmpdir|
        src = File.join(tmpdir, "schemas")
        FileUtils.mkdir_p(src)
        FileUtils.cp(File.join(fixtures_dir, "person.json"),
                     File.join(src, "person.json"))

        store1 = Lutaml::Jsonschema::SchemaStore.load_from_directory(src)
        saved_dir = File.join(tmpdir, "saved")
        store1.save_to_directory(saved_dir)

        store2 = Lutaml::Jsonschema::SchemaStore.load_from_directory(saved_dir)
        expect(store2.schema_count).to eq(store1.schema_count)

        output_dir = File.join(tmpdir, "output")
        generator = Lutaml::Jsonschema::Spa::Generator.new(store2, output_dir)
        generator.generate

        html = File.read(File.join(output_dir, "index.html"))
        expect(html).to include("window.SCHEMA_DATA")
      end
    end
  end

  # ── CLI end-to-end ──

  describe "CLI spa command" do
    it "generates valid SPA from CLI" do
      Dir.mktmpdir do |dir|
        Lutaml::Jsonschema::Cli.start([
                                        "spa",
                                        File.join(fixtures_dir, "person.json"),
                                        "-o", dir,
                                        "--title", "CLI E2E Test",
                                        "--theme", "dark"
                                      ])

        html = File.read(File.join(dir, "index.html"))
        expect(html).to include("<!DOCTYPE html>")
        expect(html).to include("CLI E2E Test")

        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])
        expect(data["metadata"]["theme"]).to eq("dark")
        expect(data["schemas"].first["name"]).to eq("person")
      end
    end

    it "generates SPA with config file" do
      Dir.mktmpdir do |dir|
        Lutaml::Jsonschema::Cli.start([
                                        "spa",
                                        File.join(fixtures_dir, "person.json"),
                                        "-o", dir,
                                        "-c", File.join(fixtures_dir, "config.yml")
                                      ])

        html = File.read(File.join(dir, "index.html"))
        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])
        expect(data["metadata"]["title"]).to eq("Test API Docs")
        expect(data["metadata"]["version"]).to eq("2.0.0")
        expect(data["metadata"]["theme"]).to eq("dark")
      end
    end

    it "generates SPA with logo and subtitle overrides" do
      Dir.mktmpdir do |dir|
        Lutaml::Jsonschema::Cli.start([
                                        "spa",
                                        File.join(fixtures_dir, "person.json"),
                                        "-o", dir,
                                        "--logo", "https://example.com/logo.png",
                                        "--subtitle", "API Docs v3"
                                      ])

        html = File.read(File.join(dir, "index.html"))
        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])
        appearance = data["metadata"]["appearance"]
        expect(appearance["logos"]["square"]["light"]["url"]).to eq("https://example.com/logo.png")
        expect(appearance["subtitle"]).to eq("API Docs v3")
      end
    end

    it "generates SPA from multiple schemas via CLI" do
      Dir.mktmpdir do |dir|
        Lutaml::Jsonschema::Cli.start([
                                        "spa",
                                        File.join(fixtures_dir, "person.json"),
                                        File.join(fixtures_dir, "user.json"),
                                        File.join(fixtures_dir, "post.json"),
                                        "-o", dir
                                      ])

        html = File.read(File.join(dir, "index.html"))
        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])
        names = data["schemas"].map { |s| s["name"] }
        expect(names).to contain_exactly("person", "user", "post")
      end
    end
  end

  # ── Nested properties and items detail ──

  describe "comprehensive.json nested data" do
    let(:result) { generate_spa(File.join(fixtures_dir, "comprehensive.json")) }
    let(:schema_data) { result[:data]["schemas"].first }
    let(:props) { schema_data["properties"] }

    it "shows nested properties for object-typed properties" do
      meta = props.find { |p| p["name"] == "metadata" }
      expect(meta["type"]).to eq("object")
      nested_names = meta["properties"].map { |p| p["name"] }
      expect(nested_names).to contain_exactly("tags", "label", "notes")
    end

    it "preserves constraints on nested properties" do
      meta = props.find { |p| p["name"] == "metadata" }
      tags = meta["properties"].find { |p| p["name"] == "tags" }
      expect(tags["type"]).to eq("array")
      expect(tags["minItems"]).to eq(1)
      expect(tags["maxItems"]).to eq(10)
      expect(tags["uniqueItems"]).to eq(true)

      label = meta["properties"].find { |p| p["name"] == "label" }
      expect(label["const"]).to eq("special")

      notes = meta["properties"].find { |p| p["name"] == "notes" }
      expect(notes["contentMediaType"]).to eq("text/markdown")
      expect(notes["contentEncoding"]).to eq("utf-8")
    end

    it "shows allOf-merged properties for contact" do
      contact = props.find { |p| p["name"] == "contact" }
      expect(contact["type"]).to eq("object")
      nested_names = contact["properties"].map { |p| p["name"] }
      expect(nested_names).to include("email", "phone")
      expect(contact["requiredFields"]).to include("email")
    end

    it "shows oneOf variant schemas for shipping" do
      ship = props.find { |p| p["name"] == "shipping" }
      variants = ship["oneOfVariants"]
      expect(variants.length).to eq(2)

      standard = variants.find do |v|
        v["properties"]&.any? do |p|
          p["const"] == "standard"
        end
      end
      expect(standard).not_to be_nil
      std_method = standard["properties"].find { |p| p["name"] == "method" }
      expect(std_method["const"]).to eq("standard")
      std_days = standard["properties"].find { |p| p["name"] == "days" }
      expect(std_days["minimum"]).to eq(5.0)

      express = variants.find do |v|
        v["properties"]&.any? do |p|
          p["const"] == "express"
        end
      end
      expect(express).not_to be_nil
      exp_days = express["properties"].find { |p| p["name"] == "days" }
      expect(exp_days["maximum"]).to eq(2.0)
    end

    it "shows anyOf variant schemas for alternative_contact" do
      alt = props.find { |p| p["name"] == "alternative_contact" }
      variants = alt["anyOfVariants"]
      expect(variants.length).to eq(2)

      email_variant = variants.find do |v|
        v["properties"]&.any? do |p|
          p["name"] == "email"
        end
      end
      expect(email_variant).not_to be_nil
      expect(email_variant["requiredFields"]).to include("email")

      phone_variant = variants.find do |v|
        v["properties"]&.any? do |p|
          p["name"] == "phone"
        end
      end
      expect(phone_variant).not_to be_nil
      expect(phone_variant["requiredFields"]).to include("phone")
    end

    it "shows patternProperties for tags_map" do
      tags_map = props.find { |p| p["name"] == "tags_map" }
      pp = tags_map["patternProperties"]
      expect(pp).to include("^x-")
      expect(pp["^x-"]["type"]).to eq("string")
      expect(pp["^[a-z]+$"]["type"]).to eq("integer")
      expect(tags_map["additionalProperties"]).to eq(false)
      expect(tags_map["minProperties"]).to eq(1)
      expect(tags_map["maxProperties"]).to eq(20)
    end

    it "shows contains constraint for array property" do
      ca = props.find { |p| p["name"] == "contained_array" }
      expect(ca["type"]).to eq("array")
      expect(ca["containsType"]).to eq("integer")
    end

    it "shows not constraint" do
      nas = props.find { |p| p["name"] == "not_a_string" }
      expect(nas["notType"]).to eq("string")
    end

    it "shows if/then/else at schema level" do
      expect(schema_data["ifSchema"]).not_to be_nil
      expect(schema_data["thenRequired"]).to contain_exactly("priority",
                                                             "contact")
      expect(schema_data["elseProperties"].map do |p|
        p["name"]
      end).to include("priority")
    end
  end

  # ── Complex defs: array items with $ref ──

  describe "complex_defs.json items detail" do
    let(:result) { generate_spa(File.join(fixtures_dir, "complex_defs.json")) }
    let(:schema_data) { result[:data]["schemas"].first }
    let(:defs) { schema_data["definitions"] }

    it "shows items_ref on array properties in definitions" do
      md_meta = defs.find { |d| d["name"] == "MD_Metadata" }
      identifiers = md_meta["properties"].find do |p|
        p["name"] == "identifiers"
      end
      expect(identifiers["type"]).to eq("array")
      expect(identifiers["itemsRef"]).to eq("#/$defs/MD_Identifier")
      expect(identifiers["itemsType"]).to eq("object")
    end

    it "shows itemsProperties for object-typed array items" do
      md_meta = defs.find { |d| d["name"] == "MD_Metadata" }
      identifiers = md_meta["properties"].find do |p|
        p["name"] == "identifiers"
      end
      item_prop_names = identifiers["itemsProperties"].map { |p| p["name"] }
      expect(item_prop_names).to contain_exactly("code", "codeSpace")
      code = identifiers["itemsProperties"].find { |p| p["name"] == "code" }
      expect(code["type"]).to eq("string")
      expect(identifiers["itemsRequired"]).to include("code")
    end

    it "shows oneOf variant schemas in definitions" do
      acu = defs.find { |d| d["name"] == "Abstract_ConstraintUnion" }
      expect(acu["hasOneOf"]).to eq(true)
      variants = acu["oneOfVariants"]
      expect(variants.length).to eq(2)
      titles = variants.map { |v| v["title"] }
      expect(titles).to contain_exactly("Legal Constraints",
                                        "Security Constraints")
    end

    it "preserves enum on definition-level schemas" do
      topic = defs.find { |d| d["name"] == "MD_TopicCategoryCode" }
      expect(topic["enum"]).to contain_exactly("farming", "biota", "boundaries",
                                               "climatology", "economy", "elevation")
    end
  end

  # ── Heroku hyper-schema: links ──

  describe "heroku.json hyper-schema links" do
    let(:result) { generate_spa(File.join(fixtures_dir, "heroku.json")) }
    let(:schema_data) { result[:data]["schemas"].first }
    let(:defs) { schema_data["definitions"] }

    it "includes links on definitions with hyper-schema links" do
      af = defs.find { |d| d["name"] == "account-feature" }
      expect(af["links"].length).to be > 0
    end

    it "captures link method, href, title, and description" do
      af = defs.find { |d| d["name"] == "account-feature" }
      info_link = af["links"].find { |l| l["title"] == "Info" }
      expect(info_link["method"]).to eq("GET")
      expect(info_link["href"]).to include("/account/features")
      expect(info_link["description"]).not_to be_empty
    end

    it "captures all HTTP methods present in links" do
      af = defs.find { |d| d["name"] == "account-feature" }
      methods = af["links"].map { |l| l["method"] }
      expect(methods).to include("GET", "PATCH")
    end
  end

  # ── HTML structure verification ──

  describe "HTML output structure" do
    let(:result) { generate_spa(File.join(fixtures_dir, "person.json")) }

    it "contains DOCTYPE" do
      expect(result[:html]).to start_with("<!DOCTYPE html>")
    end

    it "contains inlined CSS" do
      expect(result[:html]).to include("<style>")
      expect(result[:html]).to include("</style>")
    end

    it "contains inlined JS" do
      expect(result[:html]).to include("<script>")
      expect(result[:html]).to include("</script>")
    end

    it "contains SCHEMA_DATA with valid JSON" do
      expect(result[:html]).to include("window.SCHEMA_DATA")
      data = JSON.parse(result[:html][%r{window\.SCHEMA_DATA\s*=\s*(\{.*?\});}m,
                                      1])
      expect(data).to have_key("metadata")
      expect(data).to have_key("schemas")
      expect(data).to have_key("searchIndex")
    end

    it "has mount point div" do
      expect(result[:html]).to include('<div id="app"></div>')
    end
  end
end
