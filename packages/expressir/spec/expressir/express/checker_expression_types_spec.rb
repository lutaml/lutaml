# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "fileutils"
require "tempfile"

# TODO.sota/01 tier 2: operator domain typing per ISO 10303-11:2004
# ch.12. eengine performs no expression typing (kernel/check.lisp
# traverses structurally only), so the note id is our own.
RSpec.describe Expressir::Express::Checker do
  def notes_for(exp)
    checker = described_class.new(Expressir::Express::Parser.from_exp(exp, use_native: ENV["SPEC_RUBY"] ? false : true))
    checker.check
    checker.notes.select { |note| note.id == :check_expr_operand_domain }
  end

  # The examples run in-process (parsanol/parsanol-ruby#261): an earlier
  # parsanol build diverged after many interleaved check-parse cycles in
  # one process, so these farmed out to fresh subprocesses. The
  # interleaved-cycles isolation is pinned and green on current parsanol
  # (1.3.9x, both engines), and these examples pass in-process in the
  # same process as the rest of the suite.
  def checker_notes(exp_path, ids)
    checker = described_class.new(
      Expressir::Express::Parser.from_exp(File.read(exp_path)),
    )
    checker.check
    checker.notes
      .select { |n| ids.include?(n.id.to_s) }
      .map { |n| [n.id.to_s, n.message] }
  end

  def initializer_checker_notes(exp_path)
    checker_notes(exp_path, %w[check_expr_initializer_type])
  end

  it "accepts a domain-correct derive expression set" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_a;
        TYPE color = ENUMERATION OF (red, green); END_TYPE;
        ENTITY e;
          n : INTEGER;
          r : REAL;
          c : color;
          s1 : STRING;
        DERIVE
          sum : INTEGER := n + 1;
          scale : REAL := r * 2.0;
          flag : BOOLEAN := (c = color.red) AND (n > 1);
          e_ok : BOOLEAN := 1 IN [1, 2];
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes).to be_empty
  end

  it "flags numeric operands on a logical operator (12.4)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_b;
        ENTITY e;
          n : INTEGER;
        DERIVE
          bad : BOOLEAN := NOT 3;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("(12.4)")
  end

  it "flags cross-family value comparison (12.2.1)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_c;
        ENTITY e;
          n : INTEGER;
          s1 : STRING;
        DERIVE
          bad : BOOLEAN := n = s1;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("(12.2.1)")
  end

  it "flags mixed aggregate subset comparison (12.6)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_d;
        ENTITY e;
          items : LIST OF INTEGER;
          n : INTEGER;
        DERIVE
          bad : BOOLEAN := items <= n;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("(12.6)")
  end

  it "flags membership against a non-aggregate (12.2.3)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_e;
        ENTITY e;
          n : INTEGER;
        DERIVE
          bad : BOOLEAN := n IN 5;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("(12.2.3)")
  end

  it "flags like over a non-string (12.2.5)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_f;
        ENTITY e;
          s1 : STRING;
          n : INTEGER;
        DERIVE
          bad : BOOLEAN := s1 LIKE n;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("(12.2.5)")
  end

  it "flags interval bounds that are not mutually comparable (12.2.4)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_g;
        ENTITY e;
          s1 : STRING;
        DERIVE
          bad : BOOLEAN := {1 <= s1 <= 2};
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("(12.2.4)")
  end

  it "admits the union of an aggregate with an element singleton (12.6 table 17)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_h;
        ENTITY item; END_ENTITY;
        ENTITY e;
          items : LIST OF item;
          one : item;
        DERIVE
          more : LIST OF item := items + one;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes).to be_empty
  end

  it "never flags operands whose types it cannot decide" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_i;
        USE FROM foreign_schema (mystery);
        ENTITY e;
        DERIVE
          ok : BOOLEAN := mystery = mystery;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes).to be_empty
  end

  it "admits indexing of aggregates, strings and binaries" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_j;
        ENTITY item;
          tag : STRING;
        END_ENTITY;
        ENTITY e;
          items : LIST OF item;
          names : LIST OF STRING;
          bits : BINARY;
        DERIVE
          first_tag : STRING := items[1].tag;
          first_name : STRING := names[1];
          first_bit : BINARY := bits[1];
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes).to be_empty
  end

  it "flags indexing a non-indexable operand (12.6.1)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_k;
        ENTITY e;
          n : INTEGER;
        DERIVE
          bad : INTEGER := n[1];
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes.map(&:message).join).to include("indexing requires")
  end

  it "admits numeric widening and compatible initializers" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA exprchk_demo_l;
        TYPE color = ENUMERATION OF (red, green);
        END_TYPE;
        ENTITY item;
        END_ENTITY;
        ENTITY e;
          n : INTEGER;
          c : color;
          items : LIST OF item;
        DERIVE
          widen : REAL := n;
          same_enum : color := c;
          member : color := color.red;
          elem : item := items[1];
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    expect(notes).to be_empty
  end

  it "flags initializer type mismatches (12.11)" do
    fixture = Tempfile.new(["exprchk_mismatch", ".exp"])
    fixture.write(<<~EXPRESS)
      SCHEMA exprchk_demo_n;
        TYPE color = ENUMERATION OF (red, green);
        END_TYPE;
        TYPE other = ENUMERATION OF (up, down);
        END_TYPE;
        ENTITY e;
        DERIVE
          narrow : INTEGER := 1.5;
          wrong : color := other.up;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    fixture.close
    messages = initializer_checker_notes(fixture.path)
    fixture.unlink
    expect(messages.size).to eq(2)
    expect(messages.join).to include("(12.11)")
  end

  it "flags a non-logical WHERE expression (9.4)" do
    fixture = Tempfile.new(["exprchk_where", ".exp"])
    fixture.write(<<~EXPRESS)
      SCHEMA exprchk_where;
        ENTITY e;
          n : INTEGER;
        WHERE
          bad : n + 1;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    fixture.close
    notes = checker_notes(fixture.path, %w[check_expr_where_boolean])
    fixture.unlink
    expect(notes.map(&:first)).to include("check_expr_where_boolean")
  end

  it "flags duplicate UNIQUE labels (9.4)" do
    fixture = Tempfile.new(["exprchk_unique", ".exp"])
    fixture.write(<<~EXPRESS)
      SCHEMA exprchk_unique;
        ENTITY e;
          a : STRING;
          b : STRING;
        UNIQUE
          u1 : a;
          u1 : b;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    fixture.close
    notes = checker_notes(fixture.path, %w[check_expr_unique_duplicate])
    fixture.unlink
    expect(notes.map(&:first)).to include("check_expr_unique_duplicate")
  end

  it "flags an assignment compatibility violation (13.2.1)" do
    notes = notes_for(<<~EXPRESS)
      SCHEMA s;
        ENTITY e;
          n : INTEGER;
          s1 : STRING;
        DERIVE
          d : INTEGER := n;
        END_ENTITY;
        FUNCTION f(n : INTEGER) : INTEGER;
          LOCAL
            x : INTEGER;
          END_LOCAL;
          x := n;
          RETURN (x);
        END_FUNCTION;
      END_SCHEMA;
    EXPRESS
    expect(notes).to be_empty
  end

  it "flags an incompatible assignment (13.2.1)" do
    fixture = Tempfile.new(["exprchk_assign", ".exp"])
    fixture.write(<<~EXPRESS)
      SCHEMA exprchk_assign;
          FUNCTION f(n : INTEGER) : INTEGER;
          LOCAL
            x : STRING;
          END_LOCAL;
          x := n;
          RETURN (1);
        END_FUNCTION;
        ENTITY e;
        DERIVE
          d : INTEGER := f(1);
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    fixture.close
    notes = checker_notes(fixture.path, %w[check_expr_assignment_type])
    fixture.unlink
    expect(notes.map(&:first)).to include("check_expr_assignment_type")
  end

  it "flags a non-logical if condition (13.5)" do
    fixture = Tempfile.new(["exprchk_ifcond", ".exp"])
    fixture.write(<<~EXPRESS)
      SCHEMA exprchk_ifcond;
          FUNCTION f(n : INTEGER) : INTEGER;
          LOCAL
            x : INTEGER := 0;
          END_LOCAL;
          IF n THEN
            x := 1;
          END_IF;
          RETURN (x);
        END_FUNCTION;
        ENTITY e;
        DERIVE
          d : INTEGER := f(1);
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    fixture.close
    notes = checker_notes(fixture.path, %w[check_expr_operand_domain])
    fixture.unlink
    expect(notes.map(&:first)).to include("check_expr_operand_domain")
  end

  it "flags an incompatible function return (13.7)" do
    fixture = Tempfile.new(["exprchk_return", ".exp"])
    fixture.write(<<~EXPRESS)
      SCHEMA exprchk_return;
        FUNCTION f(n : INTEGER) : INTEGER;
          RETURN ('text');
        END_FUNCTION;
        ENTITY e;
        DERIVE
          d : INTEGER := f(1);
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
    fixture.close
    notes = checker_notes(fixture.path, %w[check_expr_return])
    fixture.unlink
    expect(notes.map(&:first)).to include("check_expr_return")
  end
end
