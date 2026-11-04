require "spec_helper"

RSpec.describe Expressir::Express::Formatter do
  describe "inline tail remarks" do
    let(:source) do
      <<~EXPRESS
        SCHEMA inline_remark_schema;
          FUNCTION probe(input : INTEGER) : LOGICAL;
            LOCAL
              total : INTEGER := 0;
            END_LOCAL;
            total := total + input; -- INLINE why we add
            -- LEADING above the return
            RETURN (TRUE);
          END_FUNCTION;
        END_SCHEMA;
      EXPRESS
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:formatted) { described_class.format(repo) }
    let(:lines) { formatted.lines.map(&:rstrip) }

    it "keeps the remark on its statement's line" do
      line = lines.find { |l| l.include?("total := total + input") }

      expect(formatted.scan("INLINE why we add").size).to eq(1)
      expect(line).to include("-- INLINE why we add")
    end

    it "does not disturb a leading remark on a neighbouring statement" do
      idx = lines.index { |l| l.include?("-- LEADING above the return") }

      expect(idx).not_to be_nil
      expect(lines[idx + 1]).to include("RETURN (TRUE);")
    end

    it "emits nothing when remarks are suppressed" do
      bare = described_class.new(no_remarks: true).format(repo)

      expect(bare).not_to include("INLINE why we add")
      expect(bare).not_to include("LEADING above the return")
    end

    it "agrees with PrettyFormatter" do
      pretty = Expressir::Express::PrettyFormatter.new.format(repo)

      expect(pretty.scan("INLINE why we add").size).to eq(1)
    end
  end
end
