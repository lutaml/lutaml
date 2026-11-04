require "spec_helper"

RSpec.describe Expressir::Express::Formatter do
  describe "remarks on filtered RULE statements" do
    # The RULE formatter drops statements that exist only to carry remarks.
    # When such a statement holds a placed remark it must survive, otherwise
    # the comment disappears from standard output while PrettyFormatter —
    # which does no filtering — still renders it.
    let(:source) do
      <<~EXPRESS
        SCHEMA rule_remark_schema;
          ENTITY thing; END_ENTITY;
          RULE probe FOR (thing);
            -- BEFORE-NULL leading comment
            ;
          WHERE
            wr1: TRUE;
          END_RULE;
        END_SCHEMA;
      EXPRESS
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }

    it "renders the comment in standard output" do
      expect(described_class.format(repo)).to include("-- BEFORE-NULL leading comment")
    end

    it "agrees with PrettyFormatter" do
      standard = described_class.format(repo).include?("BEFORE-NULL")
      pretty = Expressir::Express::PrettyFormatter.new.format(repo)
        .include?("BEFORE-NULL")

      expect(standard).to eq(pretty)
    end

    it "still filters the statement when remarks are suppressed" do
      expect(described_class.new(no_remarks: true).format(repo))
        .not_to include("BEFORE-NULL")
    end
  end
end
