# frozen_string_literal: true

require "spec_helper"

# lutaml-model 0.8.107 stopped flattening collection assignments.
# EntityDeclBuilder used to rely on that side effect when splicing
# ExplicitAttrBuilder / DeriveClauseBuilder / InverseClauseBuilder list
# results into Entity#attributes. Nested Array-of-Array attributes made
# format_declarations_entity raise
#   undefined method `kind' for an instance of Array
# (metanorma-plugin-lutaml windows ruby 3.3, expressir 2.4.33).
RSpec.describe Expressir::Model::Declarations::Entity do
  let(:exp_text) do
    <<~EXP
      SCHEMA flat_attrs;
        ENTITY multi_decl;
          a, b, c : INTEGER;
          d : STRING;
        END_ENTITY;

        ENTITY with_clauses;
          p : INTEGER;
          DERIVE
            q : INTEGER := 0;
          INVERSE
            r : SET [0:?] OF multi_decl FOR a;
          WHERE
            wr1: p >= 0;
        END_ENTITY;
      END_SCHEMA;
    EXP
  end

  def parse_ruby_path(text)
    Expressir::Express::Parser.from_exp(text, use_native: false)
  end

  def entity(repo, id)
    repo.schemas.flat_map { |s| s.entities || [] }.find { |e| e.id == id }
  end

  it "builds a flat attributes list on the Ruby parse path" do
    repo = parse_ruby_path(exp_text)
    %w[multi_decl with_clauses].each do |id|
      attrs = entity(repo, id).attributes
      expect(attrs).to all(satisfy { |a|
        a.is_a?(Expressir::Model::ModelElement) && a.respond_to?(:kind)
      }), "Entity #{id} attributes must be flat ModelElements, got #{attrs.map(&:class)}"
    end
  end

  it "keeps multi-decl explicit attrs, DERIVE and INVERSE as siblings" do
    attrs = entity(parse_ruby_path(exp_text), "with_clauses").attributes
    kinds = attrs.map(&:kind)
    expect(kinds).to include(
      Expressir::Model::Declarations::Attribute::EXPLICIT,
      Expressir::Model::Declarations::Attribute::DERIVED,
      Expressir::Model::Declarations::Attribute::INVERSE,
    )
  end

  it "formats entities without raising" do
    repo = parse_ruby_path(exp_text)
    expect { Expressir::Express::SourceFormatter.format(repo) }.not_to raise_error
    text = Expressir::Express::SourceFormatter.format(repo)
    expect(text).to include("ENTITY multi_decl")
    expect(text).to include("DERIVE")
    expect(text).to include("INVERSE")
  end

  it "splices Array builder results into a flat list (not nested)" do
    Expressir::Express::BuilderRegistry
    attr_a = Expressir::Model::Declarations::Attribute.new(id: "a")
    attr_b = Expressir::Model::Declarations::Attribute.new(id: "b")
    result = []
    Expressir::Express::Builder.append_built(result, [attr_a, attr_b])
    expect(result).to eq [attr_a, attr_b]

    result = []
    Expressir::Express::Builder.append_built(result, [[attr_a], [attr_b]])
    expect(result).to eq [attr_a, attr_b]
  end
end
