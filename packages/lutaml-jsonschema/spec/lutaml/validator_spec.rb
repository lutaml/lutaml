# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Validator do
  describe ".validate" do
    it "accepts the real-world draft-04 heroku schema" do
      document = Yeptris::JSON.load(File.read(fixture_path("heroku.json")))

      expect(described_class.validate(document, :draft4)).to eq([])
    end

    it "accepts the draft-07 person fixture" do
      document = Yeptris::JSON.load(File.read(fixture_path("person.json")))

      expect(described_class.validate(document, :draft7)).to eq([])
    end

    it "reports precise pointers for invalid documents" do
      errors = described_class.validate({ "type" => 5 }, :draft7)

      expect(errors.map(&:pointer)).to include("/type")
    end

    it "enforces draft-04 boolean exclusive bounds and rejects them in draft-07" do
      document = { "minimum" => 5, "exclusiveMinimum" => true }

      expect(described_class.validate(document, :draft4)).to eq([])
      expect(described_class.validate(document, :draft7).map(&:pointer))
        .to include("/exclusiveMinimum")
    end

    it "validates 2019-09 and 2020-12 documents against their vocabularies" do
      # rubocop:disable Naming/VariableNumber -- symbols mirror dialect names
      expect(
        described_class.validate(
          { "$schema" => "https://json-schema.org/draft/2019-09/schema",
            "if" => { "const" => 1 }, "then" => { "required" => ["a"] } },
          :draft2019_09,
        ),
      ).to eq([])
      expect(
        described_class.validate(
          { "prefixItems" => [{ "type" => "string" }],
            "unevaluatedProperties" => false },
          :draft2020_12,
        ),
      ).to eq([])
      # rubocop:enable Naming/VariableNumber
    end

    it "returns nil for dialects without a bundled meta-schema" do
      expect(described_class.validate({}, :unspecified)).to be_nil
      expect(described_class.supported?(:unspecified)).to be(false)
    end
  end

  describe "offline resolution" do
    it "indexes the vendored roots and vocabulary documents" do
      expect(described_class.document_uri_index.keys).to include(
        "https://json-schema.org/draft-04/schema",
        "https://json-schema.org/draft-07/schema",
        "https://json-schema.org/draft/2019-09/schema",
        "https://json-schema.org/draft/2019-09/meta/applicator",
        "https://json-schema.org/draft/2020-12/schema",
        "https://json-schema.org/draft/2020-12/meta/unevaluated",
      )
    end

    it "resolves every absolute $ref in the bundled corpus" do
      index = described_class.document_uri_index
      unresolved = index.values
        .flat_map { |document| absolute_refs(document) }
        .uniq
        .reject { |ref| index.key?(described_class.normalize(ref)) }

      expect(unresolved).to be_empty
    end
  end

  def absolute_refs(node)
    case node
    when Hash
      own = node["$ref"].to_s.start_with?("http") ? [node["$ref"]] : []
      own + node.values.flat_map { |value| absolute_refs(value) }
    when Array
      node.flat_map { |value| absolute_refs(value) }
    else
      []
    end
  end
end
