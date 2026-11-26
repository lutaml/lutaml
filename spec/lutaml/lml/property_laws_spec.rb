# frozen_string_literal: true

require "spec_helper"

ENV["RANTLY_VERBOSE"] ||= "0"
require "rantly"
require "rantly/rspec_extensions"
require "rantly/shrinks"
require "lutaml/lml/format"

require_relative "../../support/lml_property_support"

RSpec.describe "LML round-trip properties" do
  include LmlDocumentGenerator

  def report_seed
    warn "LML property seed: #{PropertyLawsSupport::SEED}"
  end

  def model_class(type)
    Class.new(Lutaml::Model::Serializable) do
      attribute :value, type
      lml { map :value, to: :value }
    end
  end

  def parse(source)
    Lutaml::Lml.parse_document(source)
  end

  def canonical(source)
    Lutaml::Formatter::Canonical.new(parse(source)).render
  rescue Lutaml::Lml::Error => e
    raise "#{e.message}\n--- generated source ---\n#{source}"
  end

  def normalize(node)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        next if PropertyLawsSupport::DEFAULT_VALUES[key] == value

        if key.to_s.include?("cardinality") && value.is_a?(Hash)
          next if value["min"] == "0" && value["max"] == "1"

          result[key] = value.merge("max" => unbounded(value["max"]))
          next
        end

        result[key] = normalize(value)
      end
    when Array
      node.map { |item| normalize(item) }
    else
      node
    end
  end

  def unbounded(max)
    max == "*" ? "n" : max
  end

  def model(source)
    normalize(parse(source).to_hash)
  end

  describe "L1 value fidelity" do
    it "round-trips generated typed values through to_lml/from_lml" do
      report_seed

      property = property_of do
        kind = choose(:string, :string, :string, :integer, :float, :boolean)
        value = case kind
                when :string then call(PropertyLawsSupport::STRING_GEN)
                when :integer then choose(integer, -618_435_539_813_391_527, 0)
                when :float then choose(float, 1.0e-10, 1.0e20, -1.0e-10)
                else boolean
                end
        Tuple.new([kind, value])
      end

      property.check(PropertyLawsSupport::COUNT) do |pair|
        kind = pair[0]
        value = pair[1]
        klass = model_class(PropertyLawsSupport::TYPES.fetch(kind))
        reloaded = klass.from_lml(klass.new(value: value).to_lml).value

        expect(reloaded).to eq(value), "kind=#{kind} value=#{value.inspect}"
      end
    end
  end

  describe "L2 key fidelity" do
    it "round-trips generated keys and values through the LML adapter" do
      report_seed

      property = property_of do
        Tuple.new([call(PropertyLawsSupport::STRING_GEN),
                   call(PropertyLawsSupport::STRING_GEN)])
      end

      property.check(PropertyLawsSupport::COUNT) do |pair|
        key = pair[0]
        value = pair[1]
        adapter = Lutaml::Lml::Format::Adapter::StandardAdapter
        lml = adapter.new({ "__type__" => "Data", key => value }).to_lml
        hash = adapter.instance_to_hash(parse(lml).instance)

        expect(hash).to include(key => value)
      end
    end
  end

  describe "regressions found by the laws" do
    it "quotes string values that would re-parse as other literals" do
      klass = model_class(:string)

      ["null", "01", "2dCi9o", "0x10", "1.50"].each do |value|
        reloaded = klass.from_lml(klass.new(value: value).to_lml).value

        expect(reloaded).to eq(value), "value=#{value.inspect}"
      end
    end

    it "expands exponent-notation floats into plain decimals" do
      klass = model_class(:float)

      [1.0e-10, 1.0e20, -1.0e-10].each do |value|
        expect(klass.from_lml(klass.new(value: value).to_lml).value).to eq(value)
      end
    end

    it "reads a signed number as a number" do
      reloaded = model_class(:integer)
        .from_lml("instance Data {\n  value = -618435539813391527\n}").value

      expect(reloaded).to eq(-618_435_539_813_391_527)
    end

    it "keeps a trailing colon on a quoted key" do
      adapter = Lutaml::Lml::Format::Adapter::StandardAdapter
      lml = adapter.new({ "__type__" => "Data", "key:" => "v" }).to_lml
      hash = adapter.instance_to_hash(parse(lml).instance)

      expect(hash).to include("key:" => "v")
    end

    it "renders an exponent float without exponent notation" do
      source = "instance X { a = 0.0000000001 }"
      output = canonical(source)

      expect(output).to include("a = 0.0000000001")
      expect(model(output)).to eq(model(source))
    end
  end

  describe "L3 document semantics" do
    it "preserves generated documents through parse/emit/parse" do
      report_seed

      property = property_of do
        Tuple.new(Array.new(10) { range(0, 24) })
      end

      property.check(PropertyLawsSupport::COUNT) do |params|
        source = generated_document(params)

        expect(model(canonical(source))).to eq(model(source)), "source:\n#{source}"
      end
    end
  end

  describe "L4 idempotence" do
    it "renders generated documents to a fixed point" do
      report_seed

      property = property_of do
        Tuple.new(Array.new(10) { range(0, 24) })
      end

      property.check(PropertyLawsSupport::COUNT) do |params|
        source = generated_document(params)
        once = canonical(source)

        expect(canonical(once)).to eq(once), "source:\n#{source}"
      end
    end
  end
end
