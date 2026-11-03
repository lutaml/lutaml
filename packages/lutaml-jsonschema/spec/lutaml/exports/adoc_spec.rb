# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"

RSpec.describe Lutaml::Jsonschema::Exports::Adoc do
  def schema_set_from(hash, name = "demo")
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add(name, Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash)))
    set
  end

  def render(hash, name = "demo")
    described_class.new(schema_set_from(hash, name)).render
  end

  it "renders a document title and a section per schema" do
    output = render("title" => "Pet", "type" => "object")

    expect(output).to start_with("= Pet")
    expect(output).to include("== Pet")
  end

  it "embeds into a Metanorma document: no title, namespaced anchors" do
    hash = {
      "title" => "Pet",
      "type" => "object",
      "properties" => {
        "friend" => { "$ref" => "#/definitions/pet" },
      },
      "definitions" => {
        "pet" => { "type" => "object", "properties" => { "name" => { "type" => "string" } } },
      },
    }
    output = described_class.new(schema_set_from(hash), embeddable: true).render

    expect(output).not_to start_with("= ")
    expect(output).to start_with("== Pet")
    expect(output).to include("[#def-demo-pet]")
    expect(output).to include("<<def-demo-pet,pet>>")
    # the standalone anchors stay unnamespaced
    standalone = render(hash)
    expect(standalone).to include("[#def-pet]")
  end

  it "renders a properties table with required flags and constraints" do
    output = render(
      "title" => "Pet",
      "type" => "object",
      "required" => ["name"],
      "properties" => {
        "name" => { "type" => "string", "description" => "Pet name",
                    "minLength" => 1 },
        "age" => { "type" => "integer", "minimum" => 0 },
      },
    )

    expect(output).to include("|`name` |string |Yes |Pet name; Min length: 1")
    expect(output).to include("|`age` |integer |No |Minimum: 0")
  end

  it "links $ref properties to definition anchors" do
    output = render(
      "title" => "Pet",
      "type" => "object",
      "definitions" => {
        "Tag" => {
          "title" => "Tag",
          "type" => "object",
          "properties" => { "id" => { "type" => "string" } },
        },
      },
      "properties" => { "tag" => { "$ref" => "#/definitions/Tag" } },
    )

    expect(output).to include("[#def-Tag]")
    expect(output).to include("=== Tag")
    expect(output).to include("<<def-Tag,Tag>>")
  end

  it "links named anchors to their definition names when embedded" do
    hash = {
      "type" => "object",
      "properties" => { "tag" => { "$ref" => "#tag-anchor" } },
      "$defs" => {
        "Tag" => { "$anchor" => "tag-anchor", "type" => "string" },
      },
    }
    output = described_class.new(schema_set_from(hash), embeddable: true).render

    expect(output).to include("[#def-demo-Tag]")
    expect(output).to include("<<def-demo-Tag,Tag>>")
  end

  it "preserves external schema references as URI links" do
    ref = "https://example.com/dqc.json#DataQuality"
    output = render(
      "type" => "object",
      "properties" => { "quality" => { "$ref" => ref } },
    )

    expect(output).to include("link:#{ref}[DataQuality]")
    expect(output).not_to include("<<def-dqc-json-DataQuality")
  end

  it "links escaped JSON Pointer names to the resolved definition" do
    hash = {
      "type" => "object",
      "properties" => { "value" => { "$ref" => "#/$defs/a~1b~0c" } },
      "$defs" => { "a/b~c" => { "type" => "string", "title" => "Target" } },
    }
    set = schema_set_from(hash)
    expect(set.resolve_ref("#/$defs/a~1b~0c", set.schemas["demo"]).title)
      .to eq("Target")

    output = described_class.new(set, embeddable: true).render
    expect(output).to include("[#def-demo-a-b-c]", "<<def-demo-a-b-c,a/b~c>>")
  end

  it "links a local YAML document to its rendered schema section" do
    Dir.mktmpdir do |dir|
      base = { "title" => "Base", "type" => "object" }
      entry = {
        "title" => "Entry", "type" => "object",
        "properties" => { "home" => { "$ref" => "./base.yaml" } }
      }
      File.write(File.join(dir, "base.yaml"), YAML.dump(base))
      entry_path = File.join(dir, "entry.json")
      File.write(entry_path, Yeptris::JSON.dump(entry))
      set = Lutaml::Jsonschema::SchemaSet.load_from_files(entry_path)
      expect(set.schemas.keys).to eq(["entry"])

      output = described_class.new(set, embeddable: true).render
      expect(output).to include("[#schema-base]\n== Base", "<<schema-base,Base>>")
      expect(set.schemas["base"].title).to eq("Base")
      expect(output).not_to include("<<def-entry-base-yaml")
    end
  end

  it "renders cyclic local documents once with resolvable section links" do
    Dir.mktmpdir do |dir|
      first = { "title" => "First", "type" => "object",
                "properties" => { "peer" => { "$ref" => "./second.yaml" } } }
      second = { "title" => "Second", "type" => "object",
                 "properties" => { "peer" => { "$ref" => "./first.json" } } }
      first_path = File.join(dir, "first.json")
      File.write(first_path, Yeptris::JSON.dump(first))
      File.write(File.join(dir, "second.yaml"), YAML.dump(second))
      set = Lutaml::Jsonschema::SchemaSet.load_from_files(first_path)

      output = described_class.new(set, embeddable: true).render
      expect(set.schemas.keys).to contain_exactly("first", "second")
      expect(output.scan(/^== First$/).size).to eq(1)
      expect(output.scan(/^== Second$/).size).to eq(1)
      expect(output).to include("[#schema-first]", "[#schema-second]",
                                "<<schema-first,First>>", "<<schema-second,Second>>")
    end
  end

  it "uses the target schema prefix for cross-schema definitions" do
    first = {
      "type" => "object",
      "properties" => { "own" => { "$ref" => "#/$defs/Shared" },
                        "foreign" => { "$ref" => "second#/$defs/Shared" } },
      "$defs" => { "Shared" => { "type" => "string" } },
    }
    second = { "type" => "object",
               "$defs" => { "Shared" => { "type" => "integer" } } }
    set = schema_set_from(first, "first")
    set.add("second", Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(second)))
    expect(set.resolve_ref("second#/$defs/Shared", set.schemas["first"]).type)
      .to eq("integer")

    output = described_class.new(set, embeddable: true).render
    expect(output).to include("[#def-first-Shared]", "[#def-second-Shared]")
    expect(output).to include("|`own` |<<def-first-Shared,Shared>>",
                              "|`foreign` |<<def-second-Shared,Shared>>")
  end

  it "renders tuple and closed-array types" do
    output = render(
      "title" => "Pair",
      "type" => "array",
      "prefixItems" => [{ "type" => "string" }, { "type" => "integer" }],
      "items" => false,
    )

    expect(output).to include("Type: [string, integer]")
  end

  it "renders an open tuple tail type" do
    output = render(
      "title" => "Row",
      "type" => "array",
      "items" => [{ "type" => "string" }],
      "additionalItems" => { "type" => "integer" },
    )

    expect(output).to include("Type: [string, integer]")
  end

  it "renders boolean definitions as prose" do
    output = render(
      "title" => "Flags",
      "type" => "object",
      "definitions" => { "never" => false, "anything" => true },
    )

    expect(output).to include("=== never")
    expect(output).to include("No value allowed.")
    expect(output).to include("=== anything")
    expect(output).to include("Any value.")
  end

  it "escapes table cell pipes" do
    output = render(
      "title" => "Pet",
      "type" => "object",
      "properties" => {
        "name" => { "type" => "string", "description" => "a | b" },
      },
    )

    expect(output).to include("a \\| b")
  end
end
