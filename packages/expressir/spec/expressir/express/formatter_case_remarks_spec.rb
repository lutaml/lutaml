require "spec_helper"

RSpec.describe Expressir::Express::Formatter do
  describe "remarks inside CASE bodies" do
    # A CaseAction is a label wrapper the parser gives no usable source
    # position, so CASE bodies were invisible to comment placement: an
    # action comment was dropped and an OTHERWISE comment surfaced after
    # END_CASE. Case now exposes its bodies as ordered statement regions.
    let(:source) do
      <<~EXPRESS
        SCHEMA case_remark_schema;
          FUNCTION probe(input : INTEGER) : LOGICAL;
            LOCAL
              total : INTEGER := 0;
            END_LOCAL;
            CASE input OF
              1 :
                -- ACTION leading comment
                total := 1;
              OTHERWISE :
                -- OTHERWISE leading comment
                total := 3;
            END_CASE;
            RETURN (TRUE);
          END_FUNCTION;
        END_SCHEMA;
      EXPRESS
    end
    let(:formatted) { described_class.format(Expressir::Express::Parser.from_exp(source)) }
    let(:lines) { formatted.lines.map(&:rstrip) }

    it "renders an action comment above its statement" do
      idx = lines.index { |l| l.include?("-- ACTION leading comment") }

      expect(formatted.scan("ACTION leading").size).to eq(1)
      expect(idx).not_to be_nil
      expect(lines[idx + 1]).to include("total := 1;")
    end

    it "renders an OTHERWISE comment inside the branch, not after END_CASE" do
      idx = lines.index { |l| l.include?("-- OTHERWISE leading comment") }
      end_case = lines.index { |l| l.include?("END_CASE") }

      expect(idx).not_to be_nil
      expect(lines[idx + 1]).to include("total := 3;")
      expect(idx).to be < end_case
    end

    it "emits nothing when remarks are suppressed" do
      bare = described_class.new(no_remarks: true)
        .format(Expressir::Express::Parser.from_exp(source))

      expect(bare).not_to include("leading comment")
    end
  end
end
