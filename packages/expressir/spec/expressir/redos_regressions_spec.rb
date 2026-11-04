# frozen_string_literal: true

require "spec_helper"
require "timeout"

RSpec.describe Expressir, "regexp hardening (CodeQL ReDoS alerts)" do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  def fast(&block) = Timeout.timeout(1, &block)

  describe Expressir::Express::AstKeyConverter do
    it "keeps acronym splitting" do
      expect(described_class.convert({ "HTTPParser" => 1, "SimpleId" => 2 }))
        .to eq(http_parser: 1, simple_id: 2)
    end

    it "converts a long capital run in linear time" do
      expect { fast { described_class.convert({ ("A" * 100_000) => 1 }) } }
        .not_to raise_error
    end
  end

  describe Expressir::Mapping do
    it "reads the item of an annotated link, or the bare value" do
      expect(described_class.entity_item("<<express:SCH.ITEM,ITEM>>")).to eq("ITEM")
      expect(described_class.entity_item("<<express:SCH.ITEM>>")).to eq("ITEM")
      expect(described_class.entity_item("plain")).to eq("plain")
    end

    it "scans repeated unterminated link openers in linear time" do
      expect { fast { described_class.entity_item("<<express:a," * 50_000) } }
        .not_to raise_error
      expect { fast { described_class.entity_item("<<express:" * 50_000) } }
        .not_to raise_error
    end
  end

  describe Expressir::Mapping::RefPath do
    it "tokenises a link as one token" do
      report = described_class.parse("<<express:SCH.ITEM,ITEM>> -> x")
      expect(report).to respond_to(:steps)
    end

    it "scans repeated unterminated link openers in linear time" do
      token = described_class.const_get(:TOKEN)
      expect { fast { ("<<express:a," * 50_000).scan(token) } }
        .not_to raise_error
      expect { fast { ("<<express:" * 50_000).scan(token) } }
        .not_to raise_error
    end
  end

  describe Expressir::Commands::ParityInputs do
    it "ignores block and line remarks when collecting interface names" do
      src = "(* USE FROM hidden; *)\nUSE FROM real;\n-- REFERENCE FROM nope;\nREFERENCE FROM other;"
      expect(described_class.closure_names(src)).to eq(%w[real other])
    end

    it "keeps an unclosed remark opener, as before" do
      expect(described_class.closure_names("USE FROM a; (* USE FROM b;"))
        .to eq(%w[a b])
    end

    it "strips many unclosed openers in linear time" do
      expect { fast { described_class.closure_names("(*" * 100_000) } }
        .not_to raise_error
    end
  end

  describe Expressir::Reference::GrammarCrosswalk do
    def cell(text) = described_class.send(:cell, text)

    it "escapes pipes and leaves other backslashes literal" do
      expect(cell("a|b")).to eq('a\|b')
      expect(cell("||")).to eq('\|\|')
      expect(cell("\\")).to eq("\\")
    end

    it "doubles a backslash that precedes a pipe" do
      expect(cell('a\\|b')).to eq('a\\\\\\|b')
    end
  end
end
