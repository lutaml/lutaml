# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::NodePositionIndex do
  let(:source) do
    <<~EXP
      SCHEMA demo;
      ENTITY person;
        name : STRING;
      END_ENTITY;
      END_SCHEMA;
    EXP
  end

  let(:exp_file) { Expressir::Express::Parser.from_exp(source) }
  let(:line_map) { Expressir::Express::LineMap.new(source.b) }
  let(:index) { described_class.new(exp_file, line_map) }

  it "collects every model element with a source span" do
    expect(index.nodes).not_to be_empty
    classes = index.nodes.map { |n| n[:node].class }.uniq
    expect(classes).to include(Expressir::Model::Declarations::Schema)
    expect(classes).to include(Expressir::Model::Declarations::Entity)
  end

  it "returns nodes sorted by byte position" do
    positions = index.nodes.filter_map { |n| n[:position] }
    expect(positions).to eq(positions.sort)
  end

  it "nearest_node_to prefers a node starting on the same line" do
    # Tail-remark semantics: a remark on the same line as a declaration
    # attaches to that declaration, not to the containing scope.
    name_line = source.lines.index { |l| l.include?("name : STRING") } + 1
    node = index.nearest_node_to(name_line)
    expect(node).to be_a(Expressir::Model::Declarations::Attribute)
  end

  it "nearest_node_to falls back to the containing scope when no node starts on the line" do
    # A line inside the entity body but with no declaration on it should
    # resolve to the smallest containing scope.
    entity_inner_line = source.lines.index { |l| l.include?("ENTITY person") } + 1
    node = index.nearest_node_to(entity_inner_line)
    expect(node).to be_a(Expressir::Model::Declarations::Entity)
  end

  it "node_for_end_scope_at returns the schema on its END_SCHEMA line" do
    end_line = source.lines.index { |l| l.include?("END_SCHEMA") } + 1
    content = source.lines[end_line - 1]
    node = index.node_for_end_scope_at(end_line, content)
    expect(node).to be_a(Expressir::Model::Declarations::Schema)
  end

  it "node_for_end_scope_at returns nil for a non-END line" do
    line = source.lines.index { |l| l.include?("name : STRING") } + 1
    expect(index.node_for_end_scope_at(line, source.lines[line - 1])).to be_nil
  end

  it "COLLECTION_REGISTRY lists Schema's collections" do
    expect(described_class::COLLECTION_REGISTRY[Expressir::Model::Declarations::Schema])
      .to include(:entities, :types, :functions)
  end
end
