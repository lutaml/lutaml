# frozen_string_literal: true

require "spec_helper"
require "yeptris"

# Golden version pair on the real heroku schema: derive a "next version"
# by mutating the fixture, then assert the classified report. This keeps
# the diff honest against a real-world document shape (draft-04,
# hundreds of definitions, refs, arrays).
RSpec.describe "Diff on the heroku schema (golden version pair)" do
  let(:heroku_hash) { Yeptris::JSON.load(File.read(fixture_path("heroku.json"))) }

  def parse(hash)
    Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash))
  end

  def diff(from, to)
    Lutaml::Jsonschema::Diff.between(parse(from), parse(to))
  end

  def deep_copy(hash)
    Yeptris::JSON.load(Yeptris::JSON.dump(hash))
  end

  def summary(changes)
    changes.map { |change| [change.pointer, change.classification] }
  end

  # First definition carrying both properties and requirements.
  def headline_definition
    heroku_hash["definitions"].find do |_name, body|
      body.is_a?(Hash) && body["properties"].is_a?(Hash) &&
        body["properties"].any? && body["required"].is_a?(Array) &&
        body["required"].any?
    end
  end

  it "reports no changes for an identical document" do
    expect(diff(heroku_hash, heroku_hash)).to eq([])
  end

  it "classifies a removed property in a real definition as breaking" do
    name, body = headline_definition
    property = body["properties"].keys.first
    mutated = deep_copy(heroku_hash)
    mutated["definitions"][name]["properties"].delete(property)

    changes = diff(heroku_hash, mutated)

    expect(summary(changes))
      .to include(["/definitions/#{name}/properties/#{property}", :breaking])
  end

  it "classifies an added property as additive" do
    name = headline_definition.first
    mutated = deep_copy(heroku_hash)
    mutated["definitions"][name]["properties"]["golden_added"] = {
      "type" => "string",
    }

    changes = diff(heroku_hash, mutated)

    expect(summary(changes))
      .to include(["/definitions/#{name}/properties/golden_added", :additive])
    expect(changes).not_to(be_any { |c| c.classification == :breaking })
  end

  it "classifies a description edit as cosmetic" do
    name = headline_definition.first
    mutated = deep_copy(heroku_hash)
    mutated["definitions"][name]["description"] = "revised wording"

    changes = diff(heroku_hash, mutated)

    expect(summary(changes))
      .to include(["/definitions/#{name}/description", :cosmetic])
    expect(changes).not_to(be_any { |c| c.classification == :breaking })
  end

  it "exits non-zero from the CLI when breaking changes are present" do
    name, body = headline_definition
    property = body["properties"].keys.first

    Dir.mktmpdir do |dir|
      mutated = deep_copy(heroku_hash)
      mutated["definitions"][name]["properties"].delete(property)
      old_path = File.join(dir, "old.json")
      new_path = File.join(dir, "new.json")
      File.write(old_path, Yeptris::JSON.dump(heroku_hash))
      File.write(new_path, Yeptris::JSON.dump(mutated))

      expect do
        Lutaml::Jsonschema::Cli.start(
          ["diff", old_path, new_path, "--format", "json"],
        )
      end.to raise_error(SystemExit)
    end
  end
end
