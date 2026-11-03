# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::RemarkConservation do
  describe ".untagged_texts" do
    it "reads a remark that starts a line" do
      expect(described_class.untagged_texts("-- hello\n")).to eq(["hello"])
    end

    it "reads a remark that ends a line of code" do
      expect(described_class.untagged_texts("attr : STRING; -- hello\n"))
        .to eq(["hello"])
    end

    it "leaves out embedded remarks" do
      expect(described_class.untagged_texts("(* hello *)\n")).to be_empty
    end

    it "leaves out an untagged remark with no text" do
      expect(described_class.untagged_texts("--\n")).to be_empty
    end

    it "leaves out tagged remarks" do
      expect(described_class.untagged_texts(%(--"entity.attr" hello\n)))
        .to be_empty
    end

    it "leaves out informal propositions, which the scanner reports tagged" do
      expect(described_class.untagged_texts("  --IP1: holds always\n"))
        .to be_empty
    end
  end

  describe ".tagged_pairs" do
    it "pairs a remark's tag with its text" do
      expect(described_class.tagged_pairs(%(--"entity.attr" hello\n)))
        .to eq([["entity.attr", "hello"]])
    end

    it "leaves out untagged remarks" do
      expect(described_class.tagged_pairs("-- hello\n")).to be_empty
    end

    it "tells apart one text carried under two tags" do
      express = %(--"a" same\n--"b" same\n)

      expect(described_class.tagged_pairs(express))
        .to eq([["a", "same"], ["b", "same"]])
    end

    # A tag may itself contain a colon, so joining tag and text into one
    # string would let these two collide on a single key.
    it "tells apart a colon in the tag from a colon in the text" do
      express = %(--"wr:WR1" holds\n--"wr" WR1: holds\n)

      expect(described_class.tagged_pairs(express))
        .to eq([["wr:WR1", "holds"], ["wr", "WR1: holds"]])
    end

    # A tag with no text still binds to an element, so losing it is a real
    # loss. Dropping it for having no text would hide that behind an empty
    # diff.
    it "keeps a tagged remark that carries no text" do
      expect(described_class.tagged_pairs(%(--"x"\n))).to eq([["x", ""]])
    end

    it "keeps an informal proposition declaration" do
      expect(described_class.tagged_pairs("  --IP1:\n")).to eq([["IP1", ""]])
    end
  end

  describe ".embedded_pairs" do
    it "reads an embedded remark" do
      expect(described_class.embedded_pairs("(* hello *)\n"))
        .to eq([[nil, "hello"]])
    end

    it "reads an embedded remark spanning several lines" do
      expect(described_class.embedded_pairs("(* one\ntwo *)\n"))
        .to eq([[nil, "one\ntwo"]])
    end

    it "pairs an embedded remark's tag with its text" do
      expect(described_class.embedded_pairs(%((*"entity.attr" hello *)\n)))
        .to eq([["entity.attr", "hello"]])
    end

    it "leaves out tail remarks" do
      expect(described_class.embedded_pairs("-- hello\n")).to be_empty
    end

    # A `--` inside an embedded block is content, not a tail remark, and the
    # inner `*)` closes only the nested block, not the outer one. A
    # hand-rolled per-line scanner reported a phantom remark here, which is
    # why extraction stays with the production scanner.
    it "keeps a nested block as one remark" do
      express = "(* outer (* inner *) still outer -- not a remark *)\n"

      expect(described_class.embedded_pairs(express))
        .to eq([[nil, "outer (* inner *) still outer -- not a remark"]])
    end

    # An untagged remark carries a nil tag, so these two cannot cancel each
    # other in a multiset comparison the way a bare text and a pair would.
    it "tells an untagged remark apart from a tagged one of the same text" do
      express = %((* same *)\n(*"a" same *)\n)

      expect(described_class.embedded_pairs(express))
        .to eq([[nil, "same"], ["a", "same"]])
    end

    it "leaves out an untagged remark with no text" do
      expect(described_class.embedded_pairs("(* *)\n")).to be_empty
    end

    it "keeps a tagged remark that carries no text" do
      expect(described_class.embedded_pairs(%((*"x" *)\n)))
        .to eq([["x", ""]])
    end
  end

  describe ".lost" do
    it "reports nothing when both sides match" do
      expect(described_class.lost(%w[a b], %w[b a])).to be_empty
    end

    it "reports a missing text" do
      expect(described_class.lost(%w[a b], %w[a])).to eq({ "b" => 1 })
    end

    it "reports one missing copy of a duplicated text" do
      expect(described_class.lost(%w[a a], %w[a])).to eq({ "a" => 1 })
    end

    it "reports nothing when a text was added" do
      expect(described_class.lost(%w[a], %w[a b])).to be_empty
    end
  end

  describe ".gained" do
    it "reports an added text" do
      expect(described_class.gained(%w[a], %w[a b])).to eq({ "b" => 1 })
    end

    it "reports an added copy of a duplicated text" do
      expect(described_class.gained(%w[a], %w[a a])).to eq({ "a" => 1 })
    end

    it "reports nothing when a text went missing" do
      expect(described_class.gained(%w[a b], %w[a])).to be_empty
    end
  end
end
