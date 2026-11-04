# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::RemarkScanner do
  # Helper: scan source and return the raw Remark structs.
  def scan(source)
    described_class.new(source).scan
  end

  def tail_texts(remarks)
    remarks.select(&:tail?).map(&:text)
  end

  def embedded_texts(remarks)
    remarks.select(&:embedded?).map(&:text)
  end

  describe "issue #308 regression: inline `--` inside `(* ... *)` is NOT a tail remark" do
    let(:issue_source) do
      <<~EXP
        SCHEMA mini_schema;
        (*
        This schema provides representations for items a) -- d). that are mandatory in any application.

        [NOTE]
        --
        Scenarios of the expected use are described in the introduction.
        --
        *)
        END_SCHEMA;
      EXP
    end

    it "extracts only the embedded remark and zero tail remarks" do
      remarks = scan(issue_source)

      expect(remarks.size).to eq(1)
      expect(remarks.first.format).to eq("embedded")
      expect(remarks.any?(&:tail?)).to be(false)
    end

    it "preserves the inline `--` literally inside the embedded content" do
      remark = scan(issue_source).first

      expect(remark.text).to include("items a) -- d).")
      expect(remark.text).to include("[NOTE]\n--\nScenarios")
    end
  end

  describe "nested embedded remarks (ISO 10303-11 §7.1.6)" do
    it "captures the full content of a nested embedded remark" do
      remarks = scan("(* outer (* inner *) still outer *)")

      expect(remarks.size).to eq(1)
      expect(remarks.first.format).to eq("embedded")
      expect(remarks.first.text).to eq("outer (* inner *) still outer")
    end

    it "handles three levels of nesting" do
      remarks = scan("(* a (* b (* c *) b *) a *)")
      expect(remarks.size).to eq(1)
      expect(remarks.first.text).to eq("a (* b (* c *) b *) a")
    end

    it "matches the ISO spec §7.1.6 nested-remark example" do
      source = "(* The '(*' symbol starts a remark, and the '*)' symbol ends it *)"

      remark = scan(source).first
      expect(remark.format).to eq("embedded")
      expect(remark.text).to eq(
        "The '(*' symbol starts a remark, and the '*)' symbol ends it",
      )
    end
  end

  describe "tail remarks" do
    it "extracts a simple tail remark terminated by a newline" do
      remarks = scan(<<~EXP)
        SCHEMA x;
        -- hello world
        END_SCHEMA;
      EXP

      tail = remarks.find(&:tail?)
      expect(tail).not_to be_nil
      expect(tail.text).to eq("hello world")
      expect(tail.tag).to be_nil
      expect(tail.line).to eq(2)
      expect(tail.position).to be >= 0
    end

    it "extracts a tail remark with a quoted remark tag" do
      remark = scan(%(--"schema_x.attr" tagged tail remark\n)).first

      expect(remark.tag).to eq("schema_x.attr")
      expect(remark.text).to eq("tagged tail remark")
    end

    it "extracts an IP-style informal-proposition tail tag" do
      remark = scan("-- IP1: an informal proposition\n").first

      expect(remark.tag).to eq("IP1")
      expect(remark.text).to eq("an informal proposition")
      expect(remark.format).to eq("tail")
    end

    it "strips trailing whitespace from a tail remark" do
      remarks = scan("-- tail with trailing spaces   \n")
      expect(tail_texts(remarks)).to eq(["tail with trailing spaces"])
    end

    it "extracts a tail remark that runs to end of source without a newline" do
      remarks = scan("CODE; -- end of file remark")
      expect(tail_texts(remarks)).to eq(["end of file remark"])
    end

    it "extracts a tail remark following `*)` on the same line" do
      remarks = scan("SCHEMA test;\n(* block *) -- tail after block\nEND_SCHEMA;\n")

      expect(tail_texts(remarks)).to eq(["tail after block"])
    end

    it "consumes a `(*` opened inside a tail remark with its line" do
      remarks = scan(
        "a : INTEGER; -- see (* note\nb : INTEGER; -- other\n(* real *)\n",
      )

      expect(remarks.map { |r| [r.format, r.text] }).to eq(
        [["tail", "see (* note"], ["tail", "other"], ["embedded", "real"]],
      )
    end
  end

  describe "embedded remarks" do
    it "extracts a simple single-line embedded remark" do
      remarks = scan("(* hello *)")
      expect(embedded_texts(remarks)).to eq(["hello"])
    end

    it "extracts a multi-line embedded remark" do
      remarks = scan(<<~EXP)
        (*
          first line
          second line
        *)
      EXP

      embedded = remarks.find(&:embedded?)
      expect(embedded.text).to eq("first line\n  second line")
    end

    it "extracts a tagged embedded remark" do
      remark = scan('(*"schema.entity" remark body *)').first

      expect(remark.tag).to eq("schema.entity")
      expect(remark.text).to eq("remark body")
    end

    it "preserves inline `--` inside a tagged embedded remark's content" do
      remark = scan('(*"schema.entity" body -- with dash *)').first

      expect(remark.tag).to eq("schema.entity")
      expect(remark.text).to eq("body -- with dash")
    end

    it "extracts multiple embedded remarks separated by code" do
      remarks = scan("(* first *) CODE; (* second *)\n")

      expect(remarks.map(&:format)).to eq(%w[embedded embedded])
      expect(remarks.map(&:text)).to eq(["first", "second"])
    end

    it "does not extract a tail remark from a single-line block remark" do
      remarks = scan("SCHEMA test;\n(* prose -- more prose *)\nEND_SCHEMA;\n")
      expect(remarks.map(&:format)).to eq(["embedded"])
    end
  end

  describe "string literals (ISO 10303-11 §7.1.6.5)" do
    it "does not mistake `--` inside a simple string literal for a tail remark" do
      source = "CONSTANT greeting : STRING := 'hello -- world'; END_CONSTANT;\n"

      expect(scan(source)).to eq([])
    end

    it "does not mistake `(*` inside a simple string literal for an embedded remark" do
      source = "CONSTANT note : STRING := 'see (* not a block *) here'; END_CONSTANT;\n"

      expect(scan(source)).to eq([])
    end

    it "handles the `''` escape: a doubled quote is content, not a closer" do
      # 'it''s -- ok' is the string `it's -- ok`; the `--` is inside the
      # string, so no tail remark should be emitted.
      source = "x : STRING := 'it''s -- ok';\n"

      expect(scan(source)).to eq([])
    end

    it "resumes normal scanning after a string closes" do
      source = "x : STRING := 'no -- dash'; -- real tail\n"

      remarks = scan(source)
      expect(remarks.size).to eq(1)
      expect(remarks.first.tail?).to be(true)
      expect(remarks.first.text).to eq("real tail")
    end

    it "tolerates an unclosed string by terminating the scan gracefully" do
      # No closing quote — malformed EXPRESS. Scanner should not raise and
      # should not emit any spurious remarks.
      expect(scan("x := 'never closed -- not a tail")).to eq([])
    end
  end

  describe "edge cases" do
    it "returns an empty array for empty source" do
      expect(scan("")).to eq([])
    end

    it "returns an empty array when no remarks are present" do
      expect(scan("SCHEMA x;\nEND_SCHEMA;\n")).to eq([])
    end

    it "extracts nothing from inside an unterminated block remark" do
      expect(scan("SCHEMA test;\n(* never closed\n-- not a tail\n")).to eq([])
    end

    it "tolerates an unclosed embedded remark by terminating the scan" do
      remarks = scan("(* never closed")
      expect(remarks).to eq([])
    end

    it "does not mistake `--` inside an unclosed embedded remark for a tail" do
      remarks = scan("(* never closed but has -- inside")
      expect(remarks.any?(&:tail?)).to be(false)
    end

    it "strips trailing carriage returns from tail remarks under CRLF" do
      # Tail terminates at \n; the preceding \r must not leak into the text.
      remarks = scan("CODE; -- tail remark\r\nnext line\n")

      tail = remarks.find(&:tail?)
      expect(tail.text).to eq("tail remark")
      expect(tail.text).not_to include("\r")
    end

    it "scans embedded remarks spanning CRLF lines correctly" do
      remarks = scan("(*\r\nfirst\r\nsecond\r\n*)\r\n")

      embedded = remarks.find(&:embedded?)
      expect(embedded.text).to eq("first\r\nsecond")
    end
  end

  describe "issue #126: `(*)` overlap pattern" do
    # `(*)` is a 3-char pattern where the embedded-remark opener `(*` and the
    # closer `*)` share the `*` character. Per strict ISO 10303-11 §7.1.6
    # grammar the opener and closer are distinct tokens that cannot share
    # characters, so `(*)` is technically invalid; we accept it as a 3-char
    # empty embedded remark for robustness.
    it "extracts `(*)` alone as an empty embedded remark" do
      remarks = scan("(*)")

      expect(remarks.size).to eq(1)
      expect(remarks.first).to be_embedded
      expect(remarks.first.text).to eq("")
    end

    it "preserves an outer remark when `(*)` appears inside it" do
      remarks = scan("(* test (*) here *)")

      expect(remarks.size).to eq(1)
      expect(remarks.first).to be_embedded
      expect(remarks.first.text).to eq("test (*) here")
    end

    it "handles multiple `(*)` patterns inside one remark" do
      remarks = scan("(* before (*) after (*) end *)")

      expect(remarks.size).to eq(1)
      expect(remarks.first.text).to eq("before (*) after (*) end")
    end

    it "treats `(*)` as empty nested inside a tagged embedded remark" do
      remarks = scan('(*"tag" content (*) content *)')

      expect(remarks.size).to eq(1)
      expect(remarks.first.tag).to eq("tag")
      expect(remarks.first.text).to eq("content (*) content")
    end

    it "still recognises `(* *)` and `(**)` as ordinary embedded remarks" do
      expect(scan("(* *)").first.text).to eq("")
      expect(scan("(**)").first.text).to eq("")
      expect(scan("(* a (**) c *)").first.text).to eq("a (**) c")
    end
  end

  describe "source-order and positions" do
    it "returns remarks ordered by byte position" do
      source = "-- one\n(* two *)\n-- three\n"

      expect(scan(source).map { |r| [r.position, r.format] }).to eq(
        [[0, "tail"], [7, "embedded"], [17, "tail"]],
      )
    end

    it "records plain tail remark position and line at the opening `--`" do
      source = "SCHEMA test;\n-- a tail remark\nEND_SCHEMA;\n"
      remark = scan(source).first

      expect(remark.position).to eq(source.b.index("--"))
      expect(remark.line).to eq(2)
      expect(remark.text).to eq("a tail remark")
      expect(remark.tag).to be_nil
      expect(remark.format).to eq("tail")
    end

    it "records embedded remark position and line at the opening `(*`" do
      source = "SCHEMA test;\n\n(* doc\nspans lines *)\n-- tail\n"
      embedded, tail = scan(source)

      expect(embedded.position).to eq(source.index("(*"))
      expect(embedded.line).to eq(3)
      expect(tail.line).to eq(5)
    end
  end

  describe "multibyte / encoding" do
    it "preserves multibyte remark text with byte positions" do
      source = "name : STRING; -- Name in Japanese: 名前\n"
      remark = scan(source).first

      expect(remark.text).to eq("Name in Japanese: 名前")
      expect(remark.text.encoding).to eq(Encoding::UTF_8)
      expect(remark.position).to eq(source.b.index("--"))
    end
  end

  describe "Remark value object" do
    let(:klass) { described_class::Remark }

    it "exposes predicate helpers for format" do
      expect(klass.new(format: "tail")).to be_tail
      expect(klass.new(format: "tail")).not_to be_embedded
      expect(klass.new(format: "embedded")).to be_embedded
      expect(klass.new(format: "embedded")).not_to be_tail
    end

    it "treats nil and empty tag as untagged" do
      expect(klass.new(tag: nil)).not_to be_tagged
      expect(klass.new(tag: "")).not_to be_tagged
      expect(klass.new(tag: "WR1")).to be_tagged
    end
  end
end
