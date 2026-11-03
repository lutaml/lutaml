# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::SchemaSet,
               "cross-file and anchor resolution" do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }

  describe "loading from directory" do
    let(:set) { described_class.load_from_directory(fixtures_dir) }

    it "loads all JSON files in the directory" do
      expect(set.schemas.length).to be >= 7
      expect(set.schemas.keys).to include("person", "user", "post",
                                          "comprehensive")
    end
  end

  describe "file $ref resolution (./file.json)" do
    let(:set) do
      described_class.load_from_files(
        File.join(fixtures_dir, "cross_ref_base.json"),
        File.join(fixtures_dir, "cross_ref_person.json"),
      )
    end

    it "resolves ./file.json refs to loaded schemas" do
      person = set.schemas["cross_ref_person"]
      home_ref = person.property_entries.find { |p| p.name == "home" }
      resolved = set.resolve_ref(home_ref.schema.dollar_ref, person)
      expect(resolved).not_to be_nil
      expect(resolved.definition_entries.length).to eq(1)
      expect(resolved.definition_entries.first.name).to eq("address")
    end
  end

  describe "$anchor resolution" do
    let(:set) do
      described_class.load_from_files(
        File.join(fixtures_dir, "cross_ref_base.json"),
      )
    end

    it "resolves anchor-based refs (#AnchorName)" do
      base = set.schemas["cross_ref_base"]
      resolved = set.resolve_ref("#Address", base)
      expect(resolved).not_to be_nil
      expect(resolved.title).to eq("Address")
    end
  end

  describe "validation" do
    it "reports unresolvable local refs" do
      json = JSON.generate({
                             "properties" => {
                               "foo" => { "$ref" => "#/definitions/nonexistent" },
                             },
                           })
      set = described_class.new
      schema = Lutaml::Jsonschema::Schema.from_json(json)
      set.add("broken", schema)

      errors = set.validation_errors
      expect(errors).not_to be_empty
      expect(errors.first).to include("unresolvable $ref")
      expect(errors.first).to include("#/definitions/nonexistent")
    end

    it "returns no errors for valid schemas" do
      set = described_class.load_from_files(
        File.join(fixtures_dir, "person.json"),
      )
      expect(set.validation_errors).to be_empty
    end

    it "validates! raises on unresolvable refs" do
      json = JSON.generate({
                             "properties" => {
                               "x" => { "$ref" => "#/definitions/missing" },
                             },
                           })
      set = described_class.new
      set.add("bad", Lutaml::Jsonschema::Schema.from_json(json))

      expect { set.validate! }.to raise_error(Lutaml::Jsonschema::SchemaSet::ValidationError)
    end

    it "valid? returns false on unresolvable refs" do
      json = JSON.generate({
                             "properties" => {
                               "x" => { "$ref" => "#/definitions/missing" },
                             },
                           })
      set = described_class.new
      set.add("bad", Lutaml::Jsonschema::Schema.from_json(json))

      expect(set.valid?).to eq(false)
    end
  end
end
