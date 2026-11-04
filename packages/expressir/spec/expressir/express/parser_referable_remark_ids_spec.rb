# frozen_string_literal: true

require "spec_helper"

# annotated-express#103: a remark tag may carry its own id after a colon
# (`<object>.__note:two`) so several notes or examples on one object stay
# separate and can be referred to.
RSpec.describe Expressir::Express::Parser do
  let(:repo) do
    described_class.from_exp(<<~EXP)
      SCHEMA ref_schema;
      FUNCTION check(a : INTEGER) : BOOLEAN;
        RETURN (TRUE);
      END_FUNCTION;
      ENTITY widget;
        size : INTEGER;
      WHERE
        WR1: size > 0;
      END_ENTITY;
      END_SCHEMA;

      (*"ref_schema.check"
      Case 0 refers to <<express:ref_schema.check.__note:two>>.
      *)

      (*"ref_schema.check.__note:two"
      first note
      *)

      (*"ref_schema.check.__note:3"
      second note
      *)

      (*"ref_schema.check.__note"
      anonymous note
      *)

      (*"ref_schema.check.__example:ex1"
      an example
      *)

      (*"ref_schema.widget.wr:WR1.__note:n1"
      a rule note
      *)
    EXP
  end

  let(:schema) { repo.schemas.first }

  def items(node)
    node.remark_items.to_h { |item| [item.id, item.remarks] }
  end

  it "keeps each id-bearing note and example as its own remark item" do
    expect(items(schema.functions.first)).to eq(
      "__note:two" => ["first note"],
      "__note:3" => ["second note"],
      "__note" => ["anonymous note"],
      "__example:ex1" => ["an example"],
    )
  end

  it "keeps the id on a note attached to a where rule" do
    expect(items(schema.entities.first.where_rules.first))
      .to eq("__note:n1" => ["a rule note"])
  end

  it "finds an id-bearing note by the path an express link uses" do
    expect(repo.find("ref_schema.check.__note:two").remarks)
      .to eq(["first note"])
    expect(repo.find("ref_schema.widget.wr:WR1.__note:n1").remarks)
      .to eq(["a rule note"])
  end

  it "gives figures, tables and schema-level notes their ids too" do
    other = described_class.from_exp(<<~EXP)
      SCHEMA s;
      ENTITY w; size : INTEGER; END_ENTITY;
      END_SCHEMA;
      (*"s.w.__figure:f1" a figure *)
      (*"s.w.__table:t1" a table *)
      (*"s.__note:n1" a schema note *)
    EXP

    expect(other.find("s.w.__figure:f1").remarks).to eq(["a figure"])
    expect(other.find("s.w.__table:t1").remarks).to eq(["a table"])
    expect(other.find("s.__note:n1").remarks).to eq(["a schema note"])
  end
end
