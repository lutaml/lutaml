# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::Indexes::ItemGraph do
  let(:files) do
    %w[syntax multiple].map { |stem| File.expand_path("../../../syntax/#{stem}.exp", __dir__) }
  end

  let(:repository) { Expressir::Express::Parser.from_files(files) }
  let(:graph) { described_class.new(repository) }

  it "indexes entities and types from every schema" do
    expect(graph.nodes.size).to be > 10
    expect(graph.nodes.keys).to all(match(/\A[^.]+\.[^.]+\z/))
  end

  it "records subtype edges and computes transitive closures" do
    expect(graph.subtype_edges.size).to be > 1
    any_child = graph.subtype_edges.sample.first
    closure = graph.supertypes(any_child)
    closure.each { |p| expect(graph.include?(p)).to be(true) }
  end

  it "records interface dependencies between schemas" do
    deps = graph.dependencies.flatten(1).uniq
    expect(deps.size).to be >= 1
  end

  describe "inverse and closure queries" do
    let(:layered) do
      Expressir::Express::Parser.from_exp(<<~EXP)
        SCHEMA a_schema;
        ENTITY base; END_ENTITY;
        ENTITY mid SUBTYPE OF (base); END_ENTITY;
        ENTITY tip SUBTYPE OF (mid); END_ENTITY;
        END_SCHEMA;

        SCHEMA b_schema;
        USE FROM a_schema;
        END_SCHEMA;

        SCHEMA c_schema;
        USE FROM b_schema;
        END_SCHEMA;
      EXP
    end

    let(:layered_graph) { described_class.new(layered) }

    it "answers direct subtypes and the transitive subtype closure" do
      aggregate_failures do
        expect(layered_graph.subtypes("a_schema.base")).to eq(["a_schema.mid"])
        expect(layered_graph.transitive_subtypes("a_schema.base"))
          .to contain_exactly("a_schema.mid", "a_schema.tip")
      end
    end

    it "walks the interface dependency closure transitively" do
      expect(layered_graph.dependency_closure("c_schema"))
        .to contain_exactly("b_schema", "a_schema")
    end

    it "answers the used-by direction" do
      expect(layered_graph.dependents_of("a_schema")).to eq(["b_schema"])
    end

    it "is cycle-safe on mutual imports" do
      cyclic = Expressir::Express::Parser.from_exp(<<~EXP)
        SCHEMA x_schema;
        USE FROM y_schema;
        ENTITY x; END_ENTITY;
        END_SCHEMA;

        SCHEMA y_schema;
        USE FROM x_schema;
        ENTITY y; END_ENTITY;
        END_SCHEMA;
      EXP
      g = described_class.new(cyclic)
      # a mutual-import cycle terminates with the whole cycle — including
      # the origin — in the closure
      expect(g.dependency_closure("x_schema"))
        .to contain_exactly("x_schema", "y_schema")
    end
  end
end
