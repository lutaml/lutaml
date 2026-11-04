# frozen_string_literal: true

require "spec_helper"
require "expressir"

# Issue #537: two parser gaps found by the corpus gate.
#
# 1. The entity header delimiter is required by ISO 10303-11 but the
#    real-world corpora (STEPmod resources) omit it — including with a
#    `--` remark riding the header line
#    (quantities_and_units_schema.exp:170). The header delimiter is
#    optional; the body re-anchors the parse.
# 2. Remark-only fragments (no SCHEMA wrapper — conversion artifacts)
#    parse to an empty model and raise the clean "no schema found"
#    error instead of a grammar dump, on both parse paths.
RSpec.describe Expressir::Express::Parser, "#537 parser gaps (corpus gate)" do
  let(:corpus_header_form) do
    <<~EXPRESS
      SCHEMA s;
      ENTITY qus -- stands for "quantity units", but need a very short name
        q : physical_quantity;
        us : SET[1:?] OF physical_unit; -- TODO: not defined
      UNIQUE
        UR1: q;
      END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  describe "optional entity header delimiter" do
    it "parses the corpus header form without the delimiter" do
      repo = described_class.from_exp(corpus_header_form)
      entity = repo.schemas.first.entities.first
      expect(entity.id).to eq("qus")
      expect(entity.attributes.size).to eq(2)
    end

    it "parses the delimiter-less form with and without a remark" do
      [<<~EXPRESS, <<~EXPRESS].each do |src|
        SCHEMA s;
        ENTITY a
          x : INTEGER;
        END_ENTITY;
        END_SCHEMA;
      EXPRESS
        SCHEMA s;
        ENTITY a -- c
          x : INTEGER;
        END_ENTITY;
        END_SCHEMA;
      EXPRESS
        repo = described_class.from_exp(src)
        expect(repo.schemas.first.entities.first.id).to eq("a")
      end
    end

    it "keeps accepting the standard delimiter" do
      repo = described_class.from_exp(
        "SCHEMA s; ENTITY a; x : INTEGER; END_ENTITY; END_SCHEMA;",
      )
      expect(repo.schemas.first.entities.first.id).to eq("a")
    end
  end

  describe "remark-only fragments" do
    it "raise the clean no-schema error on both parse paths" do
      [true, false].each do |native|
        expect do
          described_class.from_exp(
            "-- just a remark\n-- another\n", use_native: native
          )
        end.to raise_error(
          Expressir::SchemaNotFoundError,
          /no schema found/,
        )
      end
    end

    it "keeps parsing normal schemas" do
      repo = described_class.from_exp(
        "SCHEMA s; ENTITY a; x : INTEGER; END_ENTITY; END_SCHEMA;",
      )
      expect(repo.schemas.first.entities.first.id).to eq("a")
    end
  end
end
