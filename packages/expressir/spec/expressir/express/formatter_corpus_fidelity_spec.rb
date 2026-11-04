# frozen_string_literal: true

require "spec_helper"

# Formatter fidelity fixes from the metanorma/iso-10303 corpus gate:
# #554 SUBTYPE_CONSTRAINT ABSTRACT SUPERTYPE, #555 RULE body
# statements, #556 zero-argument calls.
RSpec.describe Expressir::Express::Formatter do
  def format_source(source)
    Expressir::Express::Parser.from_exp(source).to_s
  end

  it "keeps ABSTRACT SUPERTYPE in subtype constraint bodies (#554)" do
    out = format_source(<<~EXP)
      SCHEMA r;
      ENTITY widget; END_ENTITY;
      SUBTYPE_CONSTRAINT widget_abstract FOR widget;
      ABSTRACT SUPERTYPE;
      END_SUBTYPE_CONSTRAINT;
      END_SCHEMA;
    EXP

    expect(out).to include("ABSTRACT SUPERTYPE;")
    expect(out).not_to match(/ABSTRACT;\s*END_SUBTYPE_CONSTRAINT/)
  end

  it "keeps the statements of a RULE body (#555)" do
    out = format_source(<<~EXP)
      SCHEMA r;
      ENTITY widget; size : REAL; END_ENTITY;
      RULE widget_census FOR (widget);
      LOCAL
      big : SET OF widget := [];
      END_LOCAL;
      big := QUERY(w <* widget | w.size > 1.0);
      WHERE
      WR1: SIZEOF(big) >= 0;
      END_WHERE;
      END_RULE;
      END_SCHEMA;
    EXP

    expect(out).to include("big := QUERY(w <* widget | w.size > 1.0);")
    expect(out).to match(/END_LOCAL;\s*\n\s*big := QUERY/)
  end

  it "keeps the parentheses of zero-argument calls (#556)" do
    out = format_source(<<~EXP)
      SCHEMA r;
      ENTITY base_item; END_ENTITY;
      TYPE sub_item = SELECT (base_item); END_TYPE;
      FUNCTION f : sub_item;
      LOCAL
      default_item : sub_item := base_item() || sub_item();
      END_LOCAL;
      RETURN (default_item);
      END_FUNCTION;
      END_SCHEMA;
    EXP

    expect(out).to include("base_item() || sub_item();")
  end
end
