# frozen_string_literal: true

require "spec_helper"
require "json"
require_relative "../../support/lml_property_support"

# JSON transfer of LML documents (lutaml-lml#100, slice 1): document, class,
# enum, attribute, package, mapping-block and instance nodes. Interleaving
# order, the XML namespace and the XML/YAML bindings are open questions and
# are not asserted here.
RSpec.describe "LML JSON transfer" do
  include LmlDocumentGenerator

  # Defaults the model materialises on load; a rendering may omit them.
  let(:defaults) do
    { "visibility" => "public", "literal" => false, "is_derived" => false,
      "is_static" => false, "is_read_only" => false, "is_abstract" => false,
      "keyword" => "enumeration", "mixed_content" => false }
  end

  def parse(source)
    Lutaml::Lml.parse_document(source)
  end

  def graph(document)
    strip(document.to_hash)
  end

  # Only model defaults (and nil, which a rendering omits) are dropped;
  # literal payloads such as `value => []` or `{}` are compared as is.
  def strip(node)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        next if defaults[key] == value || value.nil?

        # JSON has no symbols: a parsed map literal's symbol keys read back as strings.
        result[key.to_s] = strip(value)
      end
    when Array then node.map { |item| strip(item) }
    else node
    end
  end

  def transfer(document)
    Lutaml::Lml::Document.from_json(document.to_json)
  end

  describe "a declared model" do
    let(:source) do
      <<~LML
        lml "1.0"

        models Shop {
          class Item < Base {
            definition "a thing for sale"
            attribute price, Float { cardinality 0..n }
            attribute kind, String { values { "a", "b" } }
            attribute sku, String { pattern /a[0-9]+/ }
            attribute note, String { default: "none" }
          }

          enum Grade {
            definition "quality"
            value "good" {
              definition "member"
            }
            value ok
          }

          package Stock {
            class Bin { attribute x, String }
            enum Size { value "s" }
          }
        }
      LML
    end
    let(:document) { parse(source) }
    let(:json) { JSON.parse(document.to_json) }

    it "renders every node kind as JSON keys" do
      names = json.values_at("classes", "enums", "packages").flatten.map { |n| n["name"] }

      expect(names).to include("Item", "Grade", "Stock")
      expect(json["packages"].first.values_at("classes", "enums").flatten.map { |n| n["name"] })
        .to contain_exactly("Bin", "Size")
    end

    it "keeps class parent, definition and attribute facets" do
      item = json["classes"].find { |c| c["name"] == "Item" }
      facets = item["attributes"].to_h { |a| [a["name"], a] }

      expect(item).to include("parent_class" => "Base", "definition" => "a thing for sale")
      expect(facets["price"]["cardinality"]).to include("min" => "0", "max" => "n")
      expect(facets["kind"]["value_set"]).to eq(%w[a b])
      expect(facets["sku"]["pattern"]).to include("a[0-9]+")
      expect(facets["note"]["properties"]).to include(a_hash_including("name" => "default", "value" => "none"))
    end

    it "parses back to the identical document graph" do
      expect(graph(transfer(document))).to eq(graph(document))
    end

    it "reaches a fixed point after one transfer" do
      once = transfer(document).to_json

      expect(Lutaml::Lml::Document.from_json(once).to_json).to eq(once)
    end
  end

  describe "the RS 3001 corpus" do
    corpus = Dir[File.expand_path("../../fixtures/rs3001/*.lml", __dir__)]
      .map { |path| File.basename(path, ".lml") }.sort

    corpus.each do |name|
      it "round-trips #{name}" do
        path = File.expand_path("../../fixtures/rs3001/#{name}.lml", __dir__)
        document = parse(File.read(path))

        expect(graph(transfer(document))).to eq(graph(document))
      end
    end
  end

  describe "empty literal values" do
    let(:source) do
      "instances Data {\n  Row \"r\" { list = [] }\n}\n"
    end

    def list(document)
      document.instances.instances.first.attributes.find { |a| a.name == "list" }
    end

    it "keeps an empty list value through a JSON round trip" do
      document = parse(source)
      reloaded = transfer(document)

      expect(list(document).to_hash).to include("value" => [])
      expect(list(reloaded).to_hash).to include("value" => [])
      expect(strip(list(reloaded).to_hash)).to eq(strip(list(document).to_hash))
    end

    it "does not strip a literal empty value when comparing graphs" do
      with_empty = { "attributes" => [{ "name" => "a", "value" => [] }] }
      without = { "attributes" => [{ "name" => "a" }] }

      expect(strip(with_empty)).not_to eq(strip(without))
      expect(strip(with_empty)).to eq(with_empty)
    end
  end

  describe "references" do
    let(:source) do
      "instances Glazes {\n  GlazeFormula \"blue_matte\" { a = 1 }\n  " \
        "CeramicTile \"t\" { glaze = ref:(Glazes.blue_matte) }\n}\n"
    end

    def glaze(document)
      document.instances.instances.last.attributes.first
    end

    it "keeps the typed reference after a JSON reload" do
      reloaded = transfer(parse(source))

      expect(glaze(reloaded).reference&.path).to eq("Glazes.blue_matte")
    end

    it "gives the same typed reference before and after" do
      document = parse(source)

      expect(glaze(transfer(document)).reference&.path).to eq(glaze(document).reference&.path)
    end
  end

  describe "generated documents" do
    it "round-trips whole documents through JSON" do
      warn "LML property seed: #{PropertyLawsSupport::SEED}"
      property = property_of { Tuple.new(Array.new(10) { range(0, 24) }) }

      property.check(PropertyLawsSupport::COUNT) do |params|
        source = generated_document(params)
        document = parse(source)

        expect(graph(transfer(document))).to eq(graph(document)), "source:\n#{source}"
      end
    end
  end
end
