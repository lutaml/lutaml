# frozen_string_literal: true

require "spec_helper"

# expressir#390: a remark trailing a mid-construct keyword (`ELSE -- why`,
# `OTHERWISE : -- why`) attaches to nothing that renders it — nothing starts
# on the line and the region's statements end on other lines — so it was
# dropped on every round trip. It now attaches to the enclosing construct
# with INLINE placement and the keyword's region, and the formatter writes
# it back after that keyword.
RSpec.describe Expressir::Express::Formatter do
  def round_trip(source)
    Expressir::Express::Parser.from_exp(source, skip_references: true)
  end

  describe "a remark trailing the ELSE line of an IF" do
    let(:source) do
      <<~EXP
        SCHEMA s;
        FUNCTION f : INTEGER;
          LOCAL v : INTEGER; END_LOCAL;
          IF 1 > 0 THEN
            v := 1;
          ELSE  -- else branch note
            v := 2;
          END_IF;
          RETURN (v);
        END_FUNCTION;
        END_SCHEMA;
      EXP
    end

    it "renders on the ELSE line" do
      out = round_trip(source).to_s
      line = out.lines.find { |l| l.include?("ELSE") }
      expect(line).to include("-- else branch note")
    end

    it "survives a reparse with the same placement" do
      model = round_trip(source)
      reparsed = round_trip(model.to_s)
      expect(reparsed.to_s).to include("-- else branch note")

      if_stmt = model.schemas.first.functions.first.statements
        .find { |s| s.is_a?(Expressir::Model::Statements::If) }
      remark = if_stmt.untagged_remarks.first
      expect(remark.placement).to eq(Expressir::Model::RemarkPlacement::INLINE)
      expect(remark.region).to eq(Expressir::Model::RemarkPlacement::ELSE_REGION)
    end
  end

  describe "a remark trailing the OTHERWISE line of a CASE" do
    let(:source) do
      <<~EXP
        SCHEMA s;
        FUNCTION g : INTEGER;
          LOCAL v : INTEGER; END_LOCAL;
          CASE 1 OF
            1 : v := 1;
            OTHERWISE : -- fallback note
              v := 2;
          END_CASE;
          RETURN (v);
        END_FUNCTION;
        END_SCHEMA;
      EXP
    end

    it "renders on the OTHERWISE line" do
      out = round_trip(source).to_s
      line = out.lines.find { |l| l.include?("OTHERWISE") }
      expect(line).to include("-- fallback note")
    end
  end
end
