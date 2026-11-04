require "spec_helper"

RSpec.describe Expressir::Express::Formatter do
  describe "comments closing a body" do
    let(:source) do
      <<~EXPRESS
        SCHEMA trailing_remark_schema;
          ENTITY thing; END_ENTITY;
          FUNCTION probe(input : INTEGER) : LOGICAL;
            LOCAL
              total : INTEGER := 0;
            END_LOCAL;
            CASE input OF
              1 :
                total := 1;
                -- CLOSES-ACTION before OTHERWISE
              OTHERWISE :
                total := 3;
                -- CLOSES-OTHERWISE before END_CASE
            END_CASE;
            BEGIN
              total := total + 1;
              -- CLOSES-COMPOUND before END
            END;
            RETURN (TRUE);

            -- CLOSES-FUNCTION after a blank line
          END_FUNCTION;
          RULE checks FOR (thing);
            ;
            -- CLOSES-RULE-BODY before WHERE
          WHERE
            wr1: TRUE;
          END_RULE;
        END_SCHEMA;
      EXPRESS
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:formatted) { described_class.format(repo) }
    let(:lines) { formatted.lines.map(&:rstrip) }

    def line_after(marker)
      idx = lines.index { |l| l.include?(marker) }
      raise "#{marker} not rendered" unless idx

      lines[idx + 1]
    end

    {
      "CLOSES-ACTION" => "OTHERWISE",
      "CLOSES-OTHERWISE" => "END_CASE",
      "CLOSES-COMPOUND" => "END;",
      "CLOSES-FUNCTION" => "END_FUNCTION",
      "CLOSES-RULE-BODY" => "WHERE",
    }.each do |marker, keyword|
      it "renders #{marker} immediately above #{keyword}" do
        expect(formatted.scan(marker).size).to eq(1)
        expect(line_after(marker)).to include(keyword)
      end
    end

    it "never leaves a comment trailing a closing keyword" do
      trailers = lines.select { |l| l =~ /END_\w+;.*--/ || l =~ /\AEND;.*--/ }

      expect(trailers).to be_empty
    end

    it "agrees with PrettyFormatter on every marker" do
      pretty = Expressir::Express::PrettyFormatter.new.format(repo)

      %w[CLOSES-ACTION CLOSES-OTHERWISE CLOSES-COMPOUND CLOSES-FUNCTION
         CLOSES-RULE-BODY].each do |marker|
        expect(pretty.scan(marker).size).to eq(formatted.scan(marker).size),
                                            "#{marker} differs between formatters"
      end
    end

    it "emits nothing when remarks are suppressed" do
      bare = described_class.new(no_remarks: true).format(repo)

      expect(bare).not_to include("CLOSES-")
    end
  end

  describe "closing keywords resolve to the construct they actually close" do
    let(:source) do
      <<~EXPRESS
        SCHEMA nesting_schema;
          FUNCTION probe(i : INTEGER) : LOGICAL;
            LOCAL
              t : INTEGER := 0;
            END_LOCAL;
            IF (i > 0) THEN
              IF (i > 5) THEN
                t := 1;
              END_IF;
              -- CLOSES-OUTER not the inner IF
            END_IF;
            RETURN (TRUE);
          END_FUNCTION;
        END_SCHEMA;
      EXPRESS
    end
    let(:lines) do
      described_class.format(Expressir::Express::Parser.from_exp(source))
        .lines.map(&:rstrip)
    end

    # Resolving by "latest node of the right class" would pick the inner IF,
    # which has already closed, and move the comment above its END_IF.
    it "attaches a comment before the outer END_IF to the outer IF" do
      idx = lines.index { |l| l.include?("CLOSES-OUTER") }
      end_ifs = lines.each_index.select { |i| lines[i].include?("END_IF") }

      expect(idx).not_to be_nil
      expect(idx).to be > end_ifs.first
      expect(idx).to be < end_ifs.last
    end
  end

  describe "RULE where section" do
    let(:source) do
      <<~EXPRESS
        SCHEMA rule_where_schema;
          ENTITY thing; END_ENTITY;
          RULE checks FOR (thing);
            ;
            -- CLOSES-BODY section head
          WHERE
            wr1 : TRUE;
            -- CLOSES-WHERE section tail
          END_RULE;
        END_SCHEMA;
      EXPRESS
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:lines) { described_class.format(repo).lines.map(&:rstrip) }

    # The body's trailing remarks render above WHERE; a comment written
    # after the last where rule must stay below it, not jump the section.
    it "keeps each comment on its own side of WHERE" do
      body = lines.index { |l| l.include?("CLOSES-BODY") }
      where = lines.index { |l| l =~ /\AWHERE\b/ }
      after = lines.index { |l| l.include?("CLOSES-WHERE") }
      end_rule = lines.index { |l| l.include?("END_RULE") }

      expect([body, where, after, end_rule]).to all(be_truthy)
      expect(body).to be < where
      expect(after).to be > where
      expect(after).to be < end_rule
    end

    it "agrees with PrettyFormatter" do
      pretty = Expressir::Express::PrettyFormatter.new.format(repo)

      expect(pretty.scan("CLOSES-WHERE").size).to eq(1)
      expect(pretty.scan("CLOSES-BODY").size).to eq(1)
    end
  end
end
