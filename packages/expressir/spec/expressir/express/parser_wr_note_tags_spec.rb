# frozen_string_literal: true

require "spec_helper"

# #562: a NOTE annotation on a where rule of a RULE — the tag
# `<schema>.<rule>.wr:WRn.__note` must resolve the `wr:` prefix to the
# where rule and land the `__note` remark item there, not attach a
# `wr` item to the rule.
RSpec.describe Expressir::Express::Parser do
  def parse(source)
    described_class.from_exp(source)
  end

  let(:repo) do
    parse(<<~EXP)
      SCHEMA trial_wr_note_schema;
      ENTITY widget;
        name : STRING;
      END_ENTITY;
      RULE widget_rule FOR (widget);
      WHERE
      WR1: SIZEOF(widget) >= 0;
      WR2: EXISTS(widget.name);
      END_RULE;
      END_SCHEMA;

      (*"trial_wr_note_schema.widget_rule"
      A rule over all widgets.
      *)

      (*"trial_wr_note_schema.widget_rule.widget"
      the set of all instances of widget
      *)

      (*"trial_wr_note_schema.widget_rule.wr:WR1"
      Trivially satisfied.
      *)

      (*"trial_wr_note_schema.widget_rule.wr:WR1.__note"
      A note attached to WR1.
      *)

      (*"trial_wr_note_schema.widget_rule.wr:WR2.__note"
      A note attached to WR2.
      *)
    EXP
  end

  let(:rule) { repo.schemas.first.rules.first }

  it "attaches the note item to the where rule, not the rule" do
    wr1 = rule.where_rules.first

    expect(wr1.remark_items.map(&:id)).to eq(["__note"])
    expect(wr1.remark_items.first.remarks)
      .to eq(["A note attached to WR1."])
    expect(rule.remark_items.map(&:id)).to eq(["widget"])
    expect(rule.remark_items.map(&:id)).not_to include("wr")
  end

  it "keeps the prefixed plain remark on the where rule" do
    wr1 = rule.where_rules.first

    expect(wr1.remarks).to eq(["Trivially satisfied."])
  end

  it "resolves each where rule's note independently" do
    wr2 = rule.where_rules[1]

    expect(wr2.remark_items.map(&:id)).to eq(["__note"])
    expect(wr2.remark_items.first.remarks)
      .to eq(["A note attached to WR2."])
  end
end
