# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::ScopeResolver do
  let(:source) do
    <<~EXP
      SCHEMA demo;
      ENTITY outer;
      END_ENTITY;
      TYPE color = ENUMERATION OF (red);
      END_TYPE;
      FUNCTION inner(name : STRING) : BOOLEAN;
        RETURN(TRUE);
      END_FUNCTION;
      END_SCHEMA;
    EXP
  end

  let(:exp_file) { Expressir::Express::Parser.from_exp(source) }
  let(:line_map) { Expressir::Express::LineMap.new(source.b) }
  let(:node_index) { Expressir::Express::NodePositionIndex.new(exp_file, line_map) }

  def resolver
    described_class.new(
      source: source,
      model: exp_file,
      nodes_with_positions: node_index.nodes,
    )
  end

  it "resolves a line inside an ENTITY to the entity" do
    line = source.lines.index { |l| l.include?("ENTITY outer") } + 1
    expect(resolver.containing_scope_for(line)).to be_a(Expressir::Model::Declarations::Entity)
  end

  it "resolves a line inside a FUNCTION to the function" do
    line = source.lines.index { |l| l.include?("RETURN(TRUE)") } + 1
    scope = resolver.containing_scope_for(line)
    expect(scope).to be_a(Expressir::Model::Declarations::Function)
    expect(scope.id).to eq("inner")
  end

  it "resolves a line before the SCHEMA to nil" do
    expect(resolver.containing_scope_for(0)).to be_nil
  end

  it "find_by_source_text locates an entity by END_ENTITY boundary" do
    end_line = source.lines.index { |l| l.include?("END_ENTITY") } + 1
    scope = resolver.find_by_source_text(end_line)
    expect(scope).to be_a(Expressir::Model::Declarations::Entity)
    expect(scope.id).to eq("outer")
  end

  it "does not trip on a TYPE END when the open was an ENTITY" do
    # Robustness against interleaved scopes (illegal in EXPRESS but the
    # stack should not pop the wrong type).
    end_type_line = source.lines.index { |l| l.include?("END_TYPE") } + 1
    scope = resolver.find_by_source_text(end_type_line)
    expect(scope).to be_a(Expressir::Model::Declarations::Type)
  end

  it "SCOPE_DECL_COLLECTIONS is a subset of COLLECTION_REGISTRY[Schema]" do
    schema_collections = Expressir::Express::NodePositionIndex::COLLECTION_REGISTRY[Expressir::Model::Declarations::Schema]
    scope_collections = Expressir::Model::Declarations::Schema::SCOPE_DECL_COLLECTIONS
    expect(scope_collections).to all(satisfy { |c| schema_collections.include?(c) })
  end

  describe "#find_by_position with the bucketed index" do
    # Synthetic positioned nodes crossing the 1024-line bucket boundary:
    # the bucketed lookup must return exactly what the linear scan did,
    # including order-sensitive innermost selection.
    let(:schema_node) { Expressir::Model::Declarations::Schema.new }
    let(:entity_node) { Expressir::Model::Declarations::Entity.new }
    let(:function_node) { Expressir::Model::Declarations::Function.new }

    def node_entry(node, line, end_line)
      { node: node, line: line, end_line: end_line, position: nil,
        owner: nil, collection: nil }
    end

    def resolver_for(nodes)
      described_class.new(source: "", model: nil, nodes_with_positions: nodes)
    end

    it "resolves a line inside a node spanning several 1024-line buckets" do
      nodes = [
        node_entry(schema_node, 1, 5000),
        node_entry(entity_node, 2000, 3000),
      ]
      expect(resolver_for(nodes).send(:find_by_position, 2_500)).to be(entity_node)
    end

    it "falls back to the outer node outside inner spans" do
      nodes = [
        node_entry(schema_node, 1, 5000),
        node_entry(entity_node, 2000, 3000),
      ]
      expect(resolver_for(nodes).send(:find_by_position, 1_500)).to be(schema_node)
    end

    it "selects the last containing scope container in index order" do
      nodes = [
        node_entry(schema_node, 1, 5000),
        node_entry(entity_node, 2000, 3000),
        node_entry(function_node, 2100, 2200),
      ]
      expect(resolver_for(nodes).send(:find_by_position, 2_150)).to be(function_node)
    end

    it "never returns Repository even when it spans the line" do
      repository = Expressir::Model::Repository.new
      nodes = [
        node_entry(repository, 1, 9999),
        node_entry(schema_node, 1, 5000),
      ]
      expect(resolver_for(nodes).send(:find_by_position, 100)).to be(schema_node)
    end

    it "returns nil when no node covers the line" do
      nodes = [node_entry(entity_node, 2000, 3000)]
      expect(resolver_for(nodes).send(:find_by_position, 4_097)).to be_nil
    end
  end
end
