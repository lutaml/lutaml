# frozen_string_literal: true

require "spec_helper"
require "expressir/scoreboard"

# TODO.compat/03: the per-command scoreboard harness. The spec keeps
# the harness cheap (single rep, no baseline IO) — the gate itself
# rides `rake scoreboard:gate` against the committed baseline.
RSpec.describe Expressir::Scoreboard do
  let(:rows) { described_class.run(reps: 1, warmup: 0) }

  it "measures every command row" do
    expect(rows.keys).to contain_exactly(
      "parse (native)", "parse (ruby)", "compare", "validate", "flatten"
    )
  end

  it "answers numeric CPU medians" do
    rows.each_value { |cpu| expect(cpu).to be_a(Numeric) }
  end

  it "renders the table" do
    table = described_class.table("parse (ruby)" => 0.01)
    expect(table).to include("| parse (ruby) | 0.0100 |")
  end

  it "gates regressions over the baseline" do
    baseline = { "row" => 1.0 }
    current_fast = { "row" => 1.1 }
    current_slow = { "row" => 2.5 }
    regressions = lambda do |current|
      current.filter_map do |row, cpu|
        base = baseline[row]
        next if base.nil? || base.zero?

        row if cpu > base * 2.0
      end
    end
    expect(regressions.call(current_fast)).to be_empty
    expect(regressions.call(current_slow)).to eq(["row"])
  end
end
