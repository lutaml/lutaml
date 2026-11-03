# frozen_string_literal: true

require "spec_helper"

# Dialect-aware rendering (TODO.sota/04): the same semantic constraint
# expressed in different drafts must render identically, and draft-only
# spellings must not leak a wrong claim into the docs.
RSpec.describe "Dialect-aware constraint rendering" do
  def spa_property(root_annotations, property_schema)
    root = {
      "type" => "object",
      "properties" => { "n" => property_schema },
    }.merge(root_annotations)
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo",
            Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(root)))
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build
    document.schemas.first.properties.first
  end

  it "renders draft-04 boolean exclusivity as its effective numeric bound" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      { "minimum" => 5, "exclusiveMinimum" => true },
    )

    expect(property.exclusive_minimum).to eq(5)
  end

  it "renders draft-06+ numeric exclusivity identically" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-06/schema#" },
      { "exclusiveMinimum" => 5 },
    )

    expect(property.exclusive_minimum).to eq(5)
  end

  it "does not claim exclusivity for a draft-04 false modifier" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      { "minimum" => 5, "exclusiveMinimum" => false },
    )

    expect(property.exclusive_minimum).to be_nil
  end

  it "renders the maximum side the same way" do
    draft4 = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      { "maximum" => 10, "exclusiveMaximum" => true },
    )
    draft7 = spa_property(
      { "$schema" => "http://json-schema.org/draft-07/schema#" },
      { "exclusiveMaximum" => 10 },
    )

    expect(draft4.exclusive_maximum).to eq(10)
    expect(draft7.exclusive_maximum).to eq(10)
  end

  it "renders draft-04 tuple items with a closed tail" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      {
        "type" => "array",
        "items" => [{ "type" => "string" }, { "type" => "integer" }],
        "additionalItems" => false,
      },
    )

    expect(property.items_tuple).to eq(%w[string integer])
    expect(property.items_closed).to be(true)
    expect(property.items_type).to be_nil
  end

  it "renders 2020-12 prefixItems with a closed tail identically" do
    draft4 = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      {
        "type" => "array",
        "items" => [{ "type" => "string" }, { "type" => "integer" }],
        "additionalItems" => false,
      },
    )
    draft2020 = spa_property(
      { "$schema" => "https://json-schema.org/draft/2020-12/schema" },
      {
        "type" => "array",
        "prefixItems" => [{ "type" => "string" }, { "type" => "integer" }],
        "items" => false,
      },
    )

    expect(draft2020.items_tuple).to eq(draft4.items_tuple)
    expect(draft2020.items_closed).to eq(draft4.items_closed)
  end

  it "renders the open tail of a tuple in both spellings" do
    draft4 = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      {
        "type" => "array",
        "items" => [{ "type" => "string" }],
        "additionalItems" => { "type" => "integer" },
      },
    )
    draft2020 = spa_property(
      { "$schema" => "https://json-schema.org/draft/2020-12/schema" },
      {
        "type" => "array",
        "prefixItems" => [{ "type" => "string" }],
        "items" => { "type" => "integer" },
      },
    )

    expect(draft4.items_tail).to eq("integer")
    expect(draft2020.items_tail).to eq("integer")
    expect(draft2020.items_closed).to be(false)
  end

  it "renders a boolean items schema as a closed array" do
    property = spa_property({}, { "type" => "array", "items" => false })

    expect(property.items_tuple).to be_nil
    expect(property.items_closed).to be(true)
  end

  it "resolves tuple item refs to their definition titles" do
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo",
            Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(
                                                   {
                                                     "type" => "object",
                                                     "$defs" => {
                                                       "Money" => {
                                                         "title" => "Money",
                                                         "type" => "object",
                                                       },
                                                     },
                                                     "properties" => {
                                                       "pair" => {
                                                         "type" => "array",
                                                         "prefixItems" => [
                                                           { "$ref" => "#/$defs/Money" },
                                                         ],
                                                         "items" => false,
                                                       },
                                                     },
                                                   },
                                                 )))
    property = Lutaml::Jsonschema::Spa::SpaBuilder.new(set)
      .build.schemas.first.properties.first

    expect(property.items_tuple).to eq(["Money"])
  end

  it "exposes items on a top-level array schema" do
    root = Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump({
                                                                     "$schema" => "https://json-schema.org/draft/2020-12/schema",
                                                                     "type" => "array",
                                                                     "prefixItems" => [{ "type" => "string" }],
                                                                     "items" => false,
                                                                   }))
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", root)
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build
    schema = document.schemas.first

    expect(schema.items_tuple).to eq(["string"])
    expect(schema.items_closed).to be(true)
    expect(Yeptris::JSON.load(document.to_json)["schemas"].first)
      .to include("itemsTuple" => ["string"], "itemsClosed" => true)
  end

  it "exposes a single-schema items type on a top-level array schema" do
    root = Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump({
                                                                     "type" => "array",
                                                                     "items" => { "type" => "integer" },
                                                                   }))
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", root)
    schema = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build.schemas.first

    expect(schema.items_type).to eq("integer")
  end

  it "renders boolean property schemas as any/never" do
    expect(spa_property({}, true).type).to eq("any")
    expect(spa_property({}, false).type).to eq("never")
  end

  it "renders boolean definitions and pattern properties" do
    root = Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump({
                                                                     "type" => "object",
                                                                     "$defs" => { "flag" => false },
                                                                     "patternProperties" => { "^x-" => true },
                                                                   }))
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", root)
    schema = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build.schemas.first

    expect(schema.definitions.first.type).to eq("never")
    expect(schema.pattern_properties).to eq("^x-" => { "type" => "any" })
  end

  it "renders boolean composition variants" do
    property = spa_property(
      {},
      { "oneOf" => [false, { "type" => "string" }] },
    )

    expect(property.one_of_variants.map(&:type)).to eq(%w[never string])
  end

  it "renders boolean not and contains constraints" do
    root = Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump({
                                                                     "type" => "array",
                                                                     "not" => false,
                                                                     "contains" => true,
                                                                   }))
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", root)
    schema = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build.schemas.first

    expect(schema.not_type).to eq("never")
    expect(schema.contains_type).to eq("any")
  end

  it "projects nested object fields and additional properties" do
    property = spa_property(
      { "$defs" => { "Extra" => { "type" => "integer" } } },
      {
        "type" => "object",
        "properties" => { "id" => { "type" => "string" } },
        "additionalProperties" => { "$ref" => "#/$defs/Extra" },
      },
    )

    expect(property.properties.map(&:name)).to eq(["id"])
    expect(property.additional_properties_ref).to eq("#/$defs/Extra")
    expect(property.additional_properties_type).to eq("integer")
  end

  it "projects x-enumDescriptions into the SPA" do
    property = spa_property(
      {},
      {
        "type" => "string",
        "enum" => %w[active archived],
        "x-enumDescriptions" => { "active" => "Currently active" },
      },
    )

    expect(property.enum_descriptions).to eq("active" => "Currently active")
    expect(property.enum).to eq(%w[active archived])
  end

  it "exposes an OpenAPI discriminator and variant refs" do
    root = Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump({
                                                                     "type" => "object",
                                                                     "$defs" => {
                                                                       "Cat" => { "type" => "object", "title" => "Cat" },
                                                                       "Dog" => { "type" => "object", "title" => "Dog" },
                                                                     },
                                                                     "properties" => {
                                                                       "pet" => {
                                                                         "oneOf" => [
                                                                           { "$ref" => "#/$defs/Cat" },
                                                                           { "$ref" => "#/$defs/Dog" },
                                                                         ],
                                                                         "discriminator" => {
                                                                           "propertyName" => "petType",
                                                                           "mapping" => {
                                                                             "cat" => "#/$defs/Cat",
                                                                             "dog" => "#/$defs/Dog",
                                                                           },
                                                                         },
                                                                       },
                                                                     },
                                                                   }))
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo", root)
    property = Lutaml::Jsonschema::Spa::SpaBuilder.new(set)
      .build.schemas.first.properties.first

    expect(property.discriminator)
      .to eq("propertyName" => "petType",
             "mapping" => { "cat" => "#/$defs/Cat",
                            "dog" => "#/$defs/Dog" })
    expect(property.one_of_variants.map(&:ref))
      .to eq(["#/$defs/Cat", "#/$defs/Dog"])
  end
end

# TODO.sota/04 closing items: `$ref` sibling semantics (draft-04 ignores
# siblings, 2019-09+ applies them) and the `format` assertion/annotation
# split — the SPA annotates the property instead of silently picking one
# meaning.
RSpec.describe "Dialect-aware $ref-sibling and format display" do
  def spa_property(root_annotations, property_schema)
    root = {
      "type" => "object",
      "properties" => { "n" => property_schema },
    }.merge(root_annotations)
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add("demo",
            Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(root)))
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(set).build
    document.schemas.first.properties.first
  end

  it "flags draft-04 $ref siblings as ignored" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      { "$ref" => "#/definitions/tag", "description" => "Tag" },
    )

    expect(property.ref_siblings_ignored).to be(true)
    expect(property.ref_siblings_apply).to be(false)
  end

  it "flags 2019-09+ $ref siblings as applied" do
    property = spa_property(
      { "$schema" => "https://json-schema.org/draft/2020-12/schema" },
      { "$ref" => "#/definitions/tag", "description" => "Tag" },
    )

    expect(property.ref_siblings_apply).to be(true)
    expect(property.ref_siblings_ignored).to be(false)
  end

  it "does not flag siblings when a $ref stands alone" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/schema#" },
      { "$ref" => "#/definitions/tag" },
    )

    expect(property.ref_siblings_ignored).to be_falsey
    expect(property.ref_siblings_apply).to be_falsey
  end

  it "marks format as asserting in draft-07 and annotating in 2020-12" do
    asserting = spa_property(
      { "$schema" => "http://json-schema.org/draft-07/schema#" },
      { "type" => "string", "format" => "email" },
    )
    expect(asserting.format_assertion).to be(true)

    annotating = spa_property(
      { "$schema" => "https://json-schema.org/draft/2020-12/schema" },
      { "type" => "string", "format" => "email" },
    )
    expect(annotating.format_assertion).to be(false)
  end

  it "reads the draft-04/07 hyper-schema metaschemas as their core dialect" do
    property = spa_property(
      { "$schema" => "http://json-schema.org/draft-04/hyper-schema#" },
      { "type" => "string", "format" => "email" },
    )

    expect(property.format_assertion).to be(true)
  end
end
