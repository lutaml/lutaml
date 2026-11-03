# frozen_string_literal: true

require "spec_helper"

# A remark trailing the opener line of a compound statement belongs on that
# opener, not after the statement's closing keyword and not on some enclosing
# block. Before this was fixed, `IF x THEN -- why` lost its remark entirely
# and REPEAT/ALIAS relocated theirs above END_REPEAT / END_ALIAS.
RSpec.describe Expressir::Express::Formatter do
  def round_trip(body)
    source = <<~EXPRESS
      SCHEMA s;
      FUNCTION f(n : INTEGER) : BOOLEAN;
        LOCAL x : INTEGER := 0; END_LOCAL;
      #{body}
        RETURN (TRUE);
      END_FUNCTION;
      END_SCHEMA;
    EXPRESS
    Expressir::Express::Parser.from_exp(source).to_s
  end

  # The remark must sit on the line carrying +anchor+, and appear once in the
  # whole output. Two emitters now read the same collection, so a substring
  # check alone would pass a remark that was written twice.
  def expect_remark_on(formatted, anchor, remark)
    line = formatted.lines.find { |l| l.include?(anchor) }

    expect(line).not_to be_nil, "no line of the output contains #{anchor}"
    expect(line).to include(remark)
    expect(formatted.scan(remark).size).to eq(1)
  end

  describe "remarks on a compound statement opener" do
    it "keeps an IF remark on the opener line" do
      formatted = round_trip(<<~EXPRESS)
        IF n > 0 THEN  -- why
          x := 1;
        END_IF;
      EXPRESS

      expect_remark_on(formatted, "IF n > 0 THEN", "-- why")
    end

    it "keeps a CASE remark on the opener line" do
      formatted = round_trip(<<~EXPRESS)
        CASE n OF  -- why
          1 : x := 2;
        END_CASE;
      EXPRESS

      expect_remark_on(formatted, "CASE n OF", "-- why")
    end

    it "keeps a REPEAT remark on the opener rather than above END_REPEAT" do
      formatted = round_trip(<<~EXPRESS)
        REPEAT i := 1 TO 3;  -- why
          x := x + i;
        END_REPEAT;
      EXPRESS

      expect_remark_on(formatted, "REPEAT i := 1 TO 3;", "-- why")
    end

    it "keeps an ALIAS remark on the opener rather than above END_ALIAS" do
      formatted = round_trip(<<~EXPRESS)
        ALIAS a FOR x;  -- why
          a := 9;
        END_ALIAS;
      EXPRESS

      expect_remark_on(formatted, "ALIAS a FOR x;", "-- why")
    end

    # The statement the remark follows must win over the block containing it.
    # Ranking candidates by where they END would hand this to the outer IF,
    # whose source spans the whole body.
    it "leaves a remark on the leaf statement it follows, not the block" do
      formatted = round_trip(<<~EXPRESS)
        IF n > 0 THEN
          x := 1; -- leaf
        END_IF;
      EXPRESS

      expect_remark_on(formatted, "x := 1;", "-- leaf")
    end

    it "gives a nested opener remark to the inner statement" do
      formatted = round_trip(<<~EXPRESS)
        IF n > 0 THEN IF n > 5 THEN  -- inner
          x := 1;
        END_IF; END_IF;
      EXPRESS

      expect_remark_on(formatted, "IF n > 5 THEN", "-- inner")
    end

    # The remark follows whichever statement starts latest on the line, not
    # whichever the precedence order happens to try first.
    it "gives the opener a remark written after a leaf on the same line" do
      formatted = round_trip(<<~EXPRESS)
        x := 0; IF n > 0 THEN  -- why
          x := 1;
        END_IF;
      EXPRESS

      expect_remark_on(formatted, "IF n > 0 THEN", "-- why")
    end

    it "keeps a BEGIN remark on the opener line" do
      formatted = round_trip(<<~EXPRESS)
        BEGIN  -- why
          x := 1;
        END;
      EXPRESS

      expect_remark_on(formatted, "BEGIN", "-- why")
    end

    # A statement can carry both kinds at once. Each has its own emitter, so
    # this is where a remark would most easily be written twice or land on the
    # wrong one of the two lines.
    it "keeps an opener and a whole statement remark on their own lines" do
      formatted = round_trip(<<~EXPRESS)
        CASE n OF 1 : x := 2; END_CASE; -- whole
        IF n > 0 THEN  -- opener
          x := 1;
        END_IF;
      EXPRESS

      expect_remark_on(formatted, "END_CASE;", "-- whole")
      expect_remark_on(formatted, "IF n > 0 THEN", "-- opener")
    end
  end

  describe "remarks on a single line statement" do
    # Unchanged behaviour, pinned because the fix reworked the same method.
    it "keeps the remark on that statement" do
      formatted = round_trip("    x := 1; -- why\n")

      expect_remark_on(formatted, "x := 1;", "-- why")
    end

    # Written on one line but rendered over several. The remark trailed the
    # whole statement, so it stays after the closing keyword; splicing it to
    # the first line like an opener remark would move it to `CASE n OF`.
    it "keeps a whole statement's remark after it when output spans lines" do
      formatted = round_trip("  CASE n OF 1 : x := 2; END_CASE; -- why\n")

      expect_remark_on(formatted, "END_CASE;", "-- why")
    end

    it "gives a shared line's remark to the last statement on it" do
      formatted = round_trip("    x := 1; x := 2; -- why\n")

      expect_remark_on(formatted, "x := 2;", "-- why")
    end
  end
end
