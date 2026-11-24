# frozen_string_literal: true

require "spec_helper"
require "json"
require_relative "../../support/lml_property_support"

# JSON transfer of the model-definition layer (lutaml-lml#100, slice 1):
# document, class, enum, attribute and package nodes. Mapping blocks,
# instances, references, interleaving order and the XML binding are open
# questions and are not asserted here.
RSpec.describe "LML JSON transfer" do
  include LmlDocumentGenerator

  # Defaults the model materialises on load; a rendering may omit them.
  let(:defaults) do
    { "visibility" => "public", "literal" => false, "is_derived" => false,
      "is_static" => false, "is_read_only" => false, "is_abstract" => false,
      "keyword" => "enumeration" }
  end

  # Layers outside this slice (mapping blocks, instances).
  let(:out_of_slice) { %w[serialization_mappings wire_mappings instance instances] }

  def parse(source)
    Lutaml::Lml.parse_document(source)
  end

  def graph(document)
    strip(document.to_hash.except(*out_of_slice))
  end

  def strip(node)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        next if defaults[key] == value || value.nil? || value == [] || value == {}

        result[key] = strip(value)
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

  describe "the RS 3001 corpus (model-definition fixtures)" do
    corpus = %w[01_class_tail_comment 02_definition_block 03_package_ceramics
                04_attribute_definition_form 05_attribute_cardinality_unbounded
                06_attribute_values_set 07_attribute_pattern
                08_attribute_default_colon 09_value_porcelain
                10_enum_glaze_technique 11_enum_values_as_instances]

    corpus.each do |name|
      it "round-trips #{name}" do
        path = File.expand_path("../../fixtures/rs3001/#{name}.lml", __dir__)
        document = parse(File.read(path))

        expect(graph(transfer(document))).to eq(graph(document))
      end
    end
  end

  describe "generated documents" do
    it "round-trips the model-definition layer through JSON" do
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
