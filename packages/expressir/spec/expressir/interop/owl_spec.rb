# frozen_string_literal: true

require "spec_helper"
require "expressir"

RSpec.describe Expressir::Interop::Owl do
  let(:schema) do
    Expressir::Express::Parser
      .from_file(Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp"))
      .schemas.first
  end

  let(:turtle) { described_class.new(schema).export }

  it "emits the ontology header and prefixes" do
    expect(turtle).to include("@prefix owl:")
    expect(turtle).to include(
      "<https://expressir.org/owl/example_geometry#> a owl:Ontology",
    )
  end

  it "maps entities to classes and supertypes to subClassOf" do
    expect(turtle).to include("ex:point a owl:Class")
    expect(turtle).to include("rdfs:subClassOf ex:geometry")
    expect(turtle).to include("rdfs:subClassOf ex:point")
  end

  it "maps defined primitive types to rdfs:Datatype" do
    expect(turtle).to include("ex:length_measure a rdfs:Datatype")
    expect(turtle).to include("owl:equivalentClass xsd:double")
  end

  it "maps attributes to properties with domain and range" do
    expect(turtle).to include("ex:x_coordinate a owl:DatatypeProperty")
    expect(turtle).to include("rdfs:domain ex:cartesian_point")
    expect(turtle).to include("rdfs:range ex:length_measure")
    expect(turtle).to include("ex:edge_start a owl:ObjectProperty")
    expect(turtle).to include("rdfs:range ex:vertex")
    expect(turtle).to include("rdfs:range rdf:List")
  end

  it "maps SELECT to a union equivalent class" do
    expect(turtle).to include(
      "owl:unionOf ( ex:edge ex:edge_logical_structure )",
    )
  end

  it "maps enumerations to classes and items to individuals" do
    enum_schema = Expressir::Express::Parser.from_exp(
      "SCHEMA s; TYPE colour = ENUMERATION OF (red, green); END_TYPE; " \
      "ENTITY e; c : colour; END_ENTITY; END_SCHEMA;",
    ).schemas.first
    output = described_class.new(enum_schema).export
    expect(output).to include("ex:colour a owl:Class")
    expect(output).to include("ex:red a owl:NamedIndividual, ex:colour .")
    expect(output).to include("ex:c a owl:ObjectProperty")
  end

  it "does not export WHERE rule bodies" do
    rule_schema = Expressir::Express::Parser.from_exp(
      "SCHEMA s; ENTITY e; x : INTEGER; WHERE positive : x > 0; END_ENTITY; " \
      "END_SCHEMA;",
    ).schemas.first
    output = described_class.new(rule_schema).export
    expect(output).not_to include("positive")
  end

  it "honours a caller-supplied base IRI" do
    output = described_class.new(schema, base_iri: "https://example.org/x#")
      .export
    expect(output).to include("@prefix ex: <https://example.org/x#> .")
    expect(output).to include("<https://example.org/x#> a owl:Ontology")
  end
end
