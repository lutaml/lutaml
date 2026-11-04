# frozen_string_literal: true

require "spec_helper"

# ISO 10303-11 subtype_constraint_body:
#   [ abstract_supertype_constraint ] [ total_over ] [ supertype_expression ] ';'
#   abstract_supertype_constraint = ABSTRACT ';'
# The ABSTRACT SUPERTYPE ';' form belongs to entity headers only (#462).
RSpec.describe Expressir::Express::Parser do
  def parse(src)
    Expressir::Express::Parser.from_exp(src)
  end

  it "parses the ABSTRACT body form (#462)" do
    repo = parse(<<~EXP)
      SCHEMA m;
      ENTITY e; END_ENTITY;
      SUBTYPE_CONSTRAINT c FOR e;
        ABSTRACT;
      END_SUBTYPE_CONSTRAINT;
      END_SCHEMA;
    EXP
    sc = repo.schemas.first.subtype_constraints.first
    aggregate_failures do
      expect(sc.id).to eq("c")
      expect(sc.abstract).to be(true)
    end
  end

  it "parses a full body with TOTAL_OVER" do
    repo = parse(<<~EXP)
      SCHEMA m;
      ENTITY base; END_ENTITY;
      ENTITY a SUBTYPE OF (base); END_ENTITY;
      ENTITY b SUBTYPE OF (base); END_ENTITY;
      SUBTYPE_CONSTRAINT c FOR base;
        ABSTRACT;
        TOTAL_OVER (a, b);
      END_SUBTYPE_CONSTRAINT;
      END_SCHEMA;
    EXP
    sc = repo.schemas.first.subtype_constraints.first
    aggregate_failures do
      expect(sc.abstract).to be(true)
      expect(sc.total_over).not_to be_nil
    end
  end

  it "round-trips the ABSTRACT body form" do
    src = <<~EXP
      SCHEMA m;

      ENTITY e;

      END_ENTITY;

      SUBTYPE_CONSTRAINT c FOR e;

      ABSTRACT;

      END_SUBTYPE_CONSTRAINT;

      END_SCHEMA;
    EXP
    repo = parse(src)
    formatted = Expressir::Express::Formatter.format(repo)
    expect(parse(formatted).schemas.first.subtype_constraints.first.abstract).to be(true)
  end

  it "round trips the ABSTRACT SUPERTYPE body form (real corpora, #554)" do
    repo = parse(<<~EXP)
      SCHEMA m;
      ENTITY e; END_ENTITY;
      SUBTYPE_CONSTRAINT c FOR e;
        ABSTRACT SUPERTYPE;
      END_SUBTYPE_CONSTRAINT;
      END_SCHEMA;
    EXP
    sc = repo.schemas.first.subtype_constraints.first
    aggregate_failures do
      expect(sc.abstract).to be(true)
      # the body's abstract_supertype production carries SUPERTYPE
      # (ISO 10303-11:2004 syntax 314 + 165); the full-schema round
      # trip is pinned in formatter_corpus_fidelity_spec
      formatted = Expressir::Express::Formatter.format(sc)
      expect(formatted).to include("ABSTRACT SUPERTYPE;")
    end
  end

  it "keeps ABSTRACT SUPERTYPE in entity headers" do
    repo = parse("SCHEMA n;\nENTITY e ABSTRACT SUPERTYPE; END_ENTITY;\nEND_SCHEMA;\n")
    expect(repo.schemas.first.entities.first.abstract).to be(true)
  end
end
