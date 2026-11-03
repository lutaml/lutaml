# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Diff do
  def schema(hash)
    Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash))
  end

  def diff(old_hash, new_hash)
    described_class.between(schema(old_hash), schema(new_hash))
  end

  def summary(changes)
    changes.map { |c| [c.pointer, c.classification] }
  end

  it "classifies an added property as additive" do
    changes = diff(
      { "type" => "object", "properties" => { "a" => { "type" => "string" } } },
      { "type" => "object", "properties" => { "a" => { "type" => "string" },
                                              "b" => { "type" => "integer" } } },
    )

    expect(summary(changes)).to include(["/properties/b", :additive])
    expect(changes).not_to(be_any { |c| c.classification == :breaking })
  end

  it "classifies a removed property as breaking" do
    changes = diff(
      { "type" => "object", "properties" => { "a" => { "type" => "string" } } },
      { "type" => "object", "properties" => {} },
    )

    expect(summary(changes)).to include(["/properties/a", :breaking])
  end

  it "classifies boolean schema transitions by openness" do
    object = { "type" => "object",
               "properties" => { "a" => { "type" => "string" } } }
    never = { "type" => "object", "properties" => { "a" => false } }
    anything = { "type" => "object", "properties" => { "a" => true } }

    expect(summary(diff(object, never)))
      .to include(["/properties/a", :breaking])
    expect(summary(diff(never, object)))
      .to include(["/properties/a", :additive])
    expect(summary(diff(object, anything)))
      .to include(["/properties/a", :additive])
    expect(summary(diff(anything, object)))
      .to include(["/properties/a", :breaking])
  end

  it "classifies requirement changes by direction" do
    base = { "type" => "object", "properties" => { "a" => {}, "b" => {} } }
    added = diff(base, base.merge("required" => ["a"]))
    removed = diff(base.merge("required" => ["a"]), base)

    expect(summary(added)).to include(["/required", :breaking])
    expect(summary(removed)).to include(["/required", :additive])
  end

  it "classifies enum narrowing as breaking and widening as additive" do
    narrowed = diff(
      { "enum" => %w[a b] },
      { "enum" => %w[a] },
    )
    widened = diff(
      { "enum" => %w[a] },
      { "enum" => %w[a b] },
    )

    expect(summary(narrowed)).to include(["/enum", :breaking])
    expect(summary(widened)).to include(["/enum", :additive])
  end

  it "classifies tightened bounds as breaking and relaxed bounds as additive" do
    tightened = diff({ "minimum" => 1 }, { "minimum" => 5 })
    relaxed = diff({ "minimum" => 5 }, { "minimum" => 1 })
    length_tightened = diff({ "maxLength" => 10 }, { "maxLength" => 5 })

    expect(summary(tightened)).to include(["/minimum", :breaking])
    expect(summary(relaxed)).to include(["/minimum", :additive])
    expect(summary(length_tightened)).to include(["/maxLength", :breaking])
  end

  it "classifies type changes and restriction changes as breaking" do
    retyped = diff({ "type" => "string" }, { "type" => "integer" })
    restricted = diff({ "additionalProperties" => true },
                      { "additionalProperties" => false })

    expect(summary(retyped)).to include(["/type", :breaking])
    expect(summary(restricted))
      .to include(["/additionalProperties", :breaking])
  end

  it "recurses into properties and definitions" do
    changes = diff(
      { "definitions" => { "x" => { "properties" => { "a" => {} } } } },
      { "definitions" => { "x" => { "properties" => {} } } },
    )

    expect(summary(changes))
      .to include(["/definitions/x/properties/a", :breaking])
  end

  it "classifies documentation-only changes as cosmetic" do
    changes = diff(
      { "type" => "object", "description" => "old" },
      { "type" => "object", "description" => "new" },
    )

    expect(summary(changes)).to include(["/description", :cosmetic])
    expect(changes).not_to(be_any { |c| c.classification == :breaking })
  end

  it "classifies retargeted $ref values as breaking" do
    changes = diff(
      { "definitions" => { "x" => { "$ref" => "#/definitions/a" } } },
      { "definitions" => { "x" => { "$ref" => "#/definitions/b" } } },
    )

    expect(summary(changes)).to include(["/definitions/x/$ref", :breaking])
  end

  it "reports breaking? correctly" do
    expect(described_class.new(schema({}), schema({}))).not_to be_breaking

    diff = described_class.new(
      schema({ "properties" => { "a" => {} } }),
      schema({ "properties" => {} }),
    )

    expect(diff).to be_breaking
  end
end
