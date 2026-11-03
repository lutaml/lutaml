# frozen_string_literal: true

require "tmpdir"
require "tempfile"
require "spec_helper"

# Round-trip fidelity fixes reported against `expressir clean`
# (GH-338, GH-339, GH-340, GH-341, GH-363): clean output must be
# semantically identical EXPRESS.
RSpec.describe Expressir::Express::Formatter do # clean round-trip fidelity (GH-338..341, GH-363)
  def format_schema(source)
    file = Tempfile.new(%w[repro .exp])
    file.write(source)
    file.close
    begin
      repo = Expressir::Express::Parser.from_file(file.path)
      Expressir::Express::Formatter.format(repo.schemas.first)
    ensure
      file.unlink
    end
  end

  it "keeps SUBTYPE OF clauses listing multiple supertypes (GH-341)" do
    out = format_schema(<<~EXP)
      SCHEMA r;
      ENTITY base_a; END_ENTITY;
      ENTITY base_b; END_ENTITY;
      ENTITY multi SUBTYPE OF (base_a, base_b); END_ENTITY;
      END_SCHEMA;
    EXP
    expect(out).to include("SUBTYPE OF (base_a, base_b)")
  end

  it "does not emit a phantom empty UNIQUE rule (GH-340)" do
    out = format_schema(<<~EXP)
      SCHEMA r;
      ENTITY thing;
        a : STRING;
        b : STRING;
      UNIQUE
        UR1: a;
        UR2: b;
      END_ENTITY;
      END_SCHEMA;
    EXP
    expect(out).to include("UR1: a;")
    expect(out).to include("UR2: b;")
    expect(out).not_to match(/;\s*;/)
  end

  it "keeps UNIQUE and OPTIONAL element modifiers on aggregations (GH-338)" do
    out = format_schema(<<~EXP)
      SCHEMA r;
      ENTITY thing; END_ENTITY;
      ENTITY holder;
        items : LIST [1:?] OF UNIQUE thing;
        arr : ARRAY [1:3] OF OPTIONAL thing;
      END_ENTITY;
      END_SCHEMA;
    EXP
    expect(out).to include("LIST [1:?] OF UNIQUE thing")
    expect(out).to include("ARRAY [1:3] OF OPTIONAL thing")
  end

  it "keeps type labels on GENERIC parameters and return types (GH-339)" do
    out = format_schema(<<~EXP)
      SCHEMA r;
      FUNCTION pick(choice1 : GENERIC : item) : GENERIC : item;
        RETURN (choice1);
      END_FUNCTION;
      END_SCHEMA;
    EXP
    expect(out).to include("GENERIC : item").twice
  end

  it "does not create empty-string remarks for empty remark blocks (GH-363)" do
    file = Tempfile.new(%w[empty-remark .exp])
    file.write(<<~EXP)
      SCHEMA s;
      ENTITY widget; name : STRING; END_ENTITY;
      RULE widget_rule FOR (widget);
      WHERE WR1: SIZEOF(widget) >= 0; END_RULE;
      END_SCHEMA;

      (*"s.widget_rule"
      A rule.
      *)

      (*"s.widget_rule.widget"
      *)
    EXP
    file.close
    begin
      repo = Expressir::Express::Parser.from_file(file.path)
      rule = repo.schemas.first.rules.first
      widget_item = rule.remark_items.find { |i| i.id == "widget" }
      expect(Array(widget_item.remarks).flat_map { |r| Array(r) }.grep(String)).to be_empty
    ensure
      file.unlink
    end
  end
end
