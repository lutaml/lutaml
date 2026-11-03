# frozen_string_literal: true

require "spec_helper"
require "expressir"

RSpec.describe Expressir::Reference::GrammarCrosswalk do
  it "maps every grammar rule to an Annex A production or a classified divergence" do
    expect(described_class.validate).to eq([])
  end

  it "accounts for every Annex A production without a dedicated rule" do
    mapped = described_class.rows.filter_map { |row| row["production"] }
      .map { |name| name.downcase.delete("_") }
    annex = File.readlines(
      Expressir.root_path.join(
        "spec/fixtures/reference/annex-ab-productions.txt",
      ),
      chomp: true,
    ).map(&:strip).reject(&:empty?)
    unaccounted = annex.reject do |production|
      mapped.include?(production.downcase.delete("_")) ||
        described_class.annex_without_rule.any? do |row|
          row["production"] == production
        end
    end
    expect(unaccounted).to eq([])
  end

  it "keeps the published guide in sync" do
    path = Expressir.root_path.join(
      "docs/_guides/reference/grammar-crosswalk.adoc",
    )
    expect(File.read(path)).to eq(described_class.render_adoc)
  end

  it "classifies the bulk of the grammar as aligned" do
    counts = described_class.rows.group_by { |row| row["status"] }
      .transform_values(&:size)
    expect(counts["aligned"]).to be > 200
    expect(counts.keys - described_class.statuses.keys).to eq([])
  end
end
