# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# ELF 5006:2025 §8 validation rules — one firing and one clean example
# per rule, against a tiny self-contained schema repository.
RSpec.describe Expressir::Mapping::RefPath do
  let(:repo) do
    Expressir::Express::Parser.from_exp(<<~EXP)
      SCHEMA demo;
      TYPE label = STRING; END_TYPE;
      TYPE colour = ENUMERATION OF (red, green); END_TYPE;
      TYPE shape_select = SELECT (widget, gadget); END_TYPE;
      ENTITY base ABSTRACT SUPERTYPE; name : label; END_ENTITY;
      ENTITY widget SUBTYPE OF (base);
        count : INTEGER;
        tags : LIST [0:?] OF label;
        shade : colour;
        pick : shape_select;
      DERIVE
        derived_count : INTEGER := count;
      END_ENTITY;
      ENTITY widget_rel;
        relating : widget;
        related : widget;
        rel_name : label;
      INVERSE
        holders : SET [0:?] OF holder FOR part;
      END_ENTITY;
      ENTITY holder;
        part : widget;
      END_ENTITY;
      ENTITY gadget; shade : colour; END_ENTITY;
      ENTITY ghost; n : STRING; END_ENTITY;
      RULE restrict_widget FOR (widget); WHERE
        WR1 : widget.count > 0;
      END_RULE;
      END_SCHEMA;
    EXP
  end

  def issues_for(path_src)
    path = described_class.parse(path_src)
    described_class.validate(path, repo, start: "widget")
  end

  it "validates a well-formed navigation end to end" do
    expect(issues_for(<<~PATH)).to be_empty
      widget <=
      base
      base.name = 'ok'
    PATH
  end

  it "flags an unknown entity (#8 entity existence)" do
    expect(issues_for("non_existent_entity <= base").map(&:message))
      .to include(a_string_including("unknown type 'non_existent_entity'"))
  end

  it "flags a false subtype claim, transitively checked (#8)" do
    expect(issues_for("widget <= ghost").map(&:message))
      .to include(a_string_including("not a subtype"))
  end

  it "accepts a transitive subtype claim" do
    expect(issues_for("widget <=\nbase").map(&:message)).to be_empty
  end

  it "flags a false supertype claim (#8)" do
    expect(issues_for("widget => base").map(&:message))
      .to include(a_string_including("not a subtype"))
  end

  it "flags a missing attribute on forward navigation (#8)" do
    expect(issues_for("widget\nwidget.nope -> gadget").map(&:message))
      .to include(a_string_including("has no attribute 'nope'"))
  end

  it "flags a type-incompatible forward navigation (#8)" do
    # count is an INTEGER: it cannot reference gadget
    expect(issues_for("widget\nwidget.count -> gadget").map(&:message))
      .to include(a_string_including("cannot reference 'gadget'"))
  end

  it "accepts a SELECT-typed attribute navigating to an option" do
    expect(issues_for("widget\nwidget.pick -> gadget").map(&:message))
      .to be_empty
  end

  it "flags inverse navigation over a missing attribute (#8)" do
    expect(issues_for("gadget <-\nwidget_rel.nope\nwidget_rel").map(&:message))
      .to include(a_string_including("has no attribute 'nope'"))
  end

  it "accepts a correct inverse navigation" do
    expect(issues_for("widget <-\nwidget_rel.related\nwidget_rel").map(&:message))
      .to be_empty
  end

  it "flags a constraint whose entity is not in the path context (#8)" do
    expect(issues_for("widget <= base\n{gadget\n gadget.shade = 'red'}")
      .map(&:message)).to include(a_string_including("not in the path context"))
  end

  it "flags a constraint on a missing attribute (#8)" do
    expect(issues_for("widget\n{widget\n widget.nope = 'x'}").map(&:message))
      .to include(a_string_including("has no attribute 'nope'"))
  end

  it "flags a constraint on a DERIVED attribute (#8)" do
    expect(issues_for("widget\n{widget\n widget.derived_count = 1}")
      .map(&:message)).to include(a_string_including("cannot be constrained"))
  end

  it "flags a wrongly typed constraint value (#8)" do
    expect(issues_for("widget\n{widget\n widget.count = 'many'}")
      .map(&:message)).to include(a_string_including("not an unquoted integer"))
  end

  it "flags a wrongly quoted constraint value (#8)" do
    expect(issues_for("widget\n{widget\n widget.count = '3'}").map(&:message))
      .to include(a_string_including("not an unquoted integer"))
  end

  it "accepts an enumeration item constraint value" do
    expect(issues_for("widget\n{widget\n widget.shade = red}").map(&:message))
      .to be_empty
  end

  it "flags a non-item enumeration constraint value (#8)" do
    expect(issues_for("widget\n{widget\n widget.shade = mauve}")
      .map(&:message)).to include(a_string_including("not an item of the enumeration"))
  end

  it "accepts a negated constraint structurally" do
    expect(issues_for("widget\n!{widget\n widget.shade = red}")
      .map(&:message)).to be_empty
  end

  it "flags a broken aggregate index (#8 aggregate rule)" do
    expect(issues_for("widget\nwidget.count[1] -> gadget").map(&:message))
      .to include(a_string_including("is not an aggregate"))
  end

  it "flags a start entity that is not the mapped entity (#8)" do
    expect(issues_for("gadget <= base").map(&:message))
      .to include(a_string_including("the mapped entity is 'widget'"))
  end

  it "flags a select extension that does not exist (#5 operators)" do
    expect(issues_for("shape_select *> colour").map(&:message))
      .to include(a_string_including("does not extend"))
  end

  describe "§5 supertype entity marker (||entity||)" do
    it "accepts a supertype of the running context" do
      expect(issues_for(<<~PATH)).to be_empty
        widget <=
        base
        ||base||
      PATH
    end

    it "flags a marker entity that is not a supertype of the context" do
      expect(issues_for("widget <= base\n||gadget||").map(&:message))
        .to include(a_string_including("is not a supertype of 'base'"))
    end

    it "flags an unknown marker entity" do
      expect(issues_for("widget <= base\n||ghost_supertype||").map(&:message))
        .to include(a_string_including("unknown type 'ghost_supertype'"))
    end
  end

  describe "§5 relationship tree marker (*entity*)" do
    it "accepts an existing relationship entity" do
      expect(issues_for(<<~PATH)).to be_empty
        widget
        *widget_rel*
      PATH
    end

    it "flags an unknown tree entity" do
      expect(issues_for("widget\n*ghost_tree*").map(&:message))
        .to include(a_string_including("unknown type 'ghost_tree'"))
    end
  end

  describe "§5 required reference path marker (<path>)" do
    it "validates the enclosed segment in the running context" do
      expect(issues_for(<<~PATH)).to be_empty
        widget
        <widget.pick -> gadget>
      PATH
    end

    it "flags a broken segment inside the marker" do
      expect(issues_for("widget\n<widget.count -> widget>").map(&:message))
        .to include(a_string_including("cannot reference 'widget'"))
    end
  end

  describe ".report (§8 validation output)" do
    it "emits a VALID verdict with the traversed entities" do
      repo = Expressir::Express::Parser.from_exp(<<~EXP)
        SCHEMA demo;
        ENTITY widget; part : widget; END_ENTITY;
        ENTITY holder; part : widget; END_ENTITY;
        END_SCHEMA;
      EXP
      report = described_class.report("widget\nwidget.part -> widget", repo,
                                      start: "widget")
      expect(report.status).to eq("VALID")
      expect(report.entities).to eq(["widget"])
      expect(report.steps).to eq(3)
    end

    it "emits an INVALID verdict with collected issues" do
      repo = Expressir::Express::Parser.from_exp(<<~EXP)
        SCHEMA demo;
        ENTITY widget; count : INTEGER; END_ENTITY;
        END_SCHEMA;
      EXP
      report = described_class.report("widget\nwidget.count -> widget", repo,
                                      start: "widget")
      expect(report.status).to eq("INVALID")
      expect(report.issues.map(&:message))
        .to include(a_string_including("cannot reference"))
    end
  end
end
