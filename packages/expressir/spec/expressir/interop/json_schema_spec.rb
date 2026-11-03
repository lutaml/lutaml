# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "json"

SHORT_NAMES = {
  "CPT" => "cartesian_point",
  "VX" => "vertex",
  "ED" => "edge",
  "ED_STRC" => "edge_logical_structure",
  "ED_LOOP" => "edge_loop",
}.freeze

RSpec.describe Expressir::Interop::JsonSchema do
  let(:schema) do
    Expressir::Express::Parser
      .from_file(Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp"))
      .schemas.first
  end

  let(:document) { described_class.new(schema).export }

  describe "mapping decisions" do
    it "composes entities through allOf over their supertypes" do
      point = document["$defs"]["cartesian_point"]
      expect(point["allOf"].first).to eq("$ref" => "#/$defs/point")
      expect(point["allOf"].last["required"])
        .to eq(%w[x_coordinate y_coordinate])
    end

    it "admits null for optional attributes and omits them from required" do
      coordinate = document["$defs"]["cartesian_point"]["allOf"].last["properties"]["z_coordinate"]
      expect(coordinate["anyOf"].last).to eq("type" => "null")
    end

    it "maps aggregates to arrays with declared bounds" do
      edges = document["$defs"]["edge_loop"]["allOf"].last["properties"]["loop_edges"]
      expect(edges["type"]).to eq("array")
      expect(edges["minItems"]).to eq(1)
      expect(edges["maxItems"]).to be_nil
    end

    it "maps SELECT to anyOf and ENUM to a string enum" do
      select = document["$defs"]["edge_or_logical"]
      expect(select["anyOf"]).to eq([
                                      { "$ref" => "#/$defs/edge" },
                                      { "$ref" => "#/$defs/edge_logical_structure" },
                                    ])
      enum = described_class.new(
        Expressir::Express::Parser.from_exp(
          "SCHEMA s; TYPE colour = ENUMERATION OF (red, green); END_TYPE; " \
          "ENTITY e; c : colour; END_ENTITY; END_SCHEMA;",
        ).schemas.first,
      ).export
      expect(enum["$defs"]["colour"]).to eq("type" => "string",
                                            "enum" => %w[red green])
    end

    it "maps defined types through to their underlying primitive" do
      measure = document["$defs"]["length_measure"]
      expect(measure).to eq("type" => "number")
    end
  end

  describe "Part 21 consumer round-trip (Annex H)" do
    let(:population) do
      Expressir::P21::Parser.parse(
        File.read(Expressir.root_path.join("spec/fixtures/p21/annex_h.p21")),
      )
    end

    it "validates the JSON serialization of the Annex H population" do
      json_population = population_document(population, schema)
      expect(json_population.size).to eq(13)
      defs = document.fetch("$defs")
      errors = population.instances.flat_map do |id, record|
        entity = entity_for(schema, record.keyword)
        validate(json_population[id], defs.fetch(entity.id), defs)
          .map { |error| "#{id}: #{error}" }
      end
      expect(errors).to eq([])
    end

    it "rejects an instance that drops a required attribute" do
      json_population = population_document(population, schema)
      json_population["#1"].delete("x_coordinate")
      errors = validate(json_population["#1"],
                        document["$defs"]["cartesian_point"],
                        document.fetch("$defs"))
      expect(errors.join).to include("missing x_coordinate")
    end
  end

  if ENV["EXPRESSIR_CONFORMANCE"]
    it "exports every schema in the stepmod resource slice" do
      stepmod = ENV["STEPMOD_DIR"] ||
        File.expand_path("~/src/mn/iso-10303-stepmod")
      corpus = File.join(stepmod, "data/resources")
      skip "stepmod corpus not present at #{corpus}" unless Dir.exist?(corpus)

      files = Dir[File.join(corpus, "**/*.exp")]
        .select { |file| File.size(file) < 250_000 }
      exported = 0
      files.each do |path|
        repository = Expressir::Express::Parser.from_file(path)
        Array(repository.schemas).each do |item|
          result = described_class.new(item).export
          expect(result["$defs"]).to be_a(Hash)
          exported += 1
        end
      rescue Parsanol::ParseFailed, Expressir::Express::Error::SchemaParseFailure
        next
      end
      expect(exported).to be > 200
    end
  end

  def population_document(population, schema)
    population.instances.transform_values do |record|
      instance_document(record, population, schema, [])
    end
  end

  def instance_document(record, population, schema, stack)
    records = record.is_a?(Expressir::P21::ComplexRecord) ? record.records : [record]
    records.each_with_object({}) do |part, result|
      entity = entity_for(schema, part.keyword)
      Expressir::P21::Validator.mapped_slots(entity).zip(part.params).each do |(attribute, _derived), value|
        result[attribute.id] = value_document(value, population, schema, stack,
                                              attribute.type)
      end
    end
  end

  def value_document(value, population, schema, stack, type = nil)
    case value
    when :unset, :derived then nil
    when Expressir::P21::Enumeration then enumeration_value(value, schema, type)
    when Expressir::P21::Binary then value.hex
    when Expressir::P21::TypedValue
      { "type" => value.keyword,
        "value" => value_document(value.value, population, schema, stack) }
    when String
      return value unless value.match?(/\A#\d+\z/)
      return { "$ref" => value } if stack.include?(value)

      instance_document(population.instances.fetch(value), population, schema,
                        stack + [value])
    when Array
      element_type = type.respond_to?(:base_type) ? type.base_type : nil
      value.map do |item|
        value_document(item, population, schema, stack, element_type)
      end
    else value
    end
  end

  def enumeration_value(value, schema, type)
    kind = resolved_type(type, schema)
    case kind
    when Expressir::Model::DataTypes::Boolean
      value.name.casecmp?("T")
    when Expressir::Model::DataTypes::Logical
      { "T" => true, "F" => false }.fetch(value.name.upcase, nil)
    else
      value.name
    end
  end

  def resolved_type(type, schema)
    return type unless type.is_a?(Expressir::Model::References::SimpleReference)

    target = schema.find(type.id)
    return type unless target.is_a?(Expressir::Model::Declarations::Type)

    resolved_type(target.underlying_type, schema)
  end

  def entity_for(schema, keyword)
    name = SHORT_NAMES[keyword] || keyword
    schema.entities.find { |entity| entity.id.casecmp?(name) }
  end

  def validate(value, schema, defs, path = "$")
    return [] if schema == true
    return ["#{path}: false schema"] if schema == false

    if (ref = schema["$ref"])
      return validate(value, defs.fetch(ref.split("/").last), defs, path)
    end

    errors = []
    Array(schema["allOf"]).each do |branch|
      errors.concat(validate(value, branch, defs, path))
    end
    if schema["anyOf"]
      branches = schema["anyOf"].map { |branch| validate(value, branch, defs, path) }
      errors << "#{path}: no anyOf branch matched" if branches.all?(&:any?)
    end
    if schema.key?("type")
      expected = Array(schema["type"])
      unless expected.any? { |type| type_matches?(value, type) }
        errors << "#{path}: expected #{expected.join('|')}"
      end
    end
    if schema["enum"] && !schema["enum"].include?(value)
      errors << "#{path}: not an enumerated value"
    end
    if schema["pattern"] && value.is_a?(String) &&
        !value.match?(Regexp.new(schema["pattern"]))
      errors << "#{path}: pattern mismatch"
    end
    if value.is_a?(Hash)
      Array(schema["required"]).each do |key|
        errors << "#{path}: missing #{key}" unless value.key?(key)
      end
      (schema["properties"] || {}).each do |key, subschema|
        next unless value.key?(key)

        errors.concat(validate(value[key], subschema, defs, "#{path}/#{key}"))
      end
    end
    if value.is_a?(Array)
      errors << "#{path}: minItems" if schema["minItems"] &&
        value.size < schema["minItems"]
      errors << "#{path}: maxItems" if schema["maxItems"] &&
        value.size > schema["maxItems"]
      errors << "#{path}: uniqueItems" if schema["uniqueItems"] &&
        value.uniq.size != value.size
      if schema["items"]
        value.each_with_index do |item, index|
          errors.concat(validate(item, schema["items"], defs,
                                 "#{path}[#{index}]"))
        end
      end
    end
    errors
  end

  def type_matches?(value, type)
    case type
    when "object" then value.is_a?(Hash)
    when "array" then value.is_a?(Array)
    when "string" then value.is_a?(String)
    when "integer" then value.is_a?(Integer)
    when "number" then value.is_a?(Numeric)
    when "boolean" then [true, false].include?(value)
    when "null" then value.nil?
    else false
    end
  end
end
