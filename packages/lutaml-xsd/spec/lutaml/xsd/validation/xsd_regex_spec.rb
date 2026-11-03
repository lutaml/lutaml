# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/xsd_regex"

RSpec.describe Lutaml::Xsd::Validation::XsdRegex do
  def match?(pattern, value)
    described_class.to_regexp(pattern).match?(value)
  end

  it "matches the whole string" do
    expect(match?("a", "ba")).to be(false)
    expect(match?("a", "ab")).to be(false)
    expect(match?("a", "a")).to be(true)
  end

  it "treats ^ and $ as literals" do
    expect(match?("\\^a", "^a")).to be(true)
    expect(match?("a$", "a$")).to be(true)
  end

  it "lets . match newlines" do
    expect(match?("a.b", "a\nb")).to be(true)
  end

  it "expands \\c for XML name characters" do
    expect(match?("\\c\\c", "a-")).to be(true)
    expect(match?("\\c\\c", "a b")).to be(false)
  end

  it "handles character-class subtraction" do
    expect(match?("[a-z-[aeiou]]", "c")).to be(true)
    expect(match?("[a-z-[aeiou]]", "e")).to be(false)
    expect(match?("[a-z-[aeiou]]+", "bcd")).to be(true)
  end

  it "normalizes \\p{Is...} block escapes" do
    expect(match?("[\\p{IsBasicLatin}]+", "abc")).to be(true)
    expect(match?("[\\p{IsBasicLatin}]+", "абв")).to be(false)
  end

  it "normalizes top-level \\p{Is...} block escapes" do
    expect(match?("\\p{IsBasicLatin}+", "abc")).to be(true)
    expect(match?("\\p{IsBasicLatin}+", "абв")).to be(false)
  end

  it "splits hyphenated and digit-bounded block names" do
    expect(match?("\\p{IsLatin-1Supplement}+", "é")).to be(true)
    expect(match?("\\p{IsLatin-1Supplement}+", "a")).to be(false)
    expect(match?("\\p{IsLatinExtended-A}+", "đ")).to be(true)
    expect(match?("\\p{IsIPAExtensions}+", "ɑ")).to be(true)
  end

  it "maps blocks Unicode renamed since XSD 1.0" do
    expect(match?("\\p{IsGreek}", "α")).to be(true)
    expect(match?("\\p{IsPrivateUse}", "")).to be(true)
  end

  it "negates block escapes with \\P" do
    expect(match?("\\P{IsBasicLatin}", "é")).to be(true)
    expect(match?("\\P{IsBasicLatin}", "a")).to be(false)
  end

  it "keeps general categories working" do
    expect(match?("\\P{L}*", "123")).to be(true)
    expect(match?("\\p{Lu}", "A")).to be(true)
    expect(match?("\\p{Lu}", "a")).to be(false)
  end

  it "keeps standard escapes working" do
    expect(match?("\\d{4}-\\d{2}", "2024-01")).to be(true)
    expect(match?("\\d{4}", "20x4")).to be(false)
  end
end
