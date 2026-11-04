# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::SchemaSet do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }

  describe "#resolve_ref with interagent fixture" do
    let(:set) do
      described_class.load_from_files(
        File.join(fixtures_dir, "interagent_simple.json"),
      )
    end
    let(:schema) { set.schemas["interagent_simple"] }

    it "resolves top-level definition ref" do
      resolved = set.resolve_ref("#/definitions/post", schema)
      expect(resolved.title).to eq("Post")
    end

    it "resolves nested definition ref" do
      resolved = set.resolve_ref("#/definitions/post/definitions/id", schema)
      expect(resolved.type).to eq("string")
      expect(resolved.format).to eq("uuid")
    end

    it "follows chained $ref (identity → id)" do
      resolved = set.resolve_ref("#/definitions/post/definitions/identity",
                                 schema)
      # identity has $ref to #/definitions/post/definitions/id, resolved transitively
      expect(resolved.type).to eq("string")
    end

    it "returns nil for non-existent ref" do
      expect(set.resolve_ref("#/definitions/nonexistent", schema)).to be_nil
    end
  end

  describe "#resolve_ref with comprehensive fixture" do
    let(:set) do
      described_class.load_from_files(
        File.join(fixtures_dir, "comprehensive.json"),
      )
    end
    let(:schema) { set.schemas["comprehensive"] }

    it "resolves $defs entries" do
      resolved = set.resolve_ref("#/definitions/email", schema)
      expect(resolved).not_to be_nil
      expect(resolved.type).to eq("object")
    end

    it "resolves $ref inside allOf" do
      contact = schema.property_entries.find { |p| p.name == "contact" }
      ref = contact.schema.all_of_values.first.dollar_ref
      resolved = set.resolve_ref(ref, schema)
      expect(resolved).not_to be_nil
      expect(resolved.type).to eq("object")
    end
  end
end
