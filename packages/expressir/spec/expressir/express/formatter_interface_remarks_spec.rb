# frozen_string_literal: true

require "spec_helper"

# A remark trailing an interface clause belongs on that clause. Before this
# was fixed the remark never reached the Interface at all: Schema did not
# list `interfaces` among its collection attributes, so the node was absent
# from the position index, and the remark fell through to the file, which the
# formatter does not emit remarks for.
RSpec.describe Expressir::Express::Formatter do
  def round_trip(interfaces)
    source = <<~EXPRESS
      SCHEMA s;
      #{interfaces}
      CONSTANT c : BOOLEAN := TRUE; END_CONSTANT;
      END_SCHEMA;
    EXPRESS
    Expressir::Express::Parser.from_exp(source).to_s
  end

  def expect_remark_on(formatted, anchor, remark)
    line = formatted.lines.find { |l| l.include?(anchor) }

    expect(line).not_to be_nil, "no line of the output contains #{anchor}"
    expect(line).to include(remark)
    expect(formatted.scan(remark).size).to eq(1)
  end

  describe "remarks on an interface clause" do
    it "keeps a REFERENCE FROM remark on its line" do
      formatted = round_trip("REFERENCE FROM other_schema; -- why\n")

      expect_remark_on(formatted, "REFERENCE FROM other_schema;", "-- why")
    end

    it "keeps a USE FROM remark on its line" do
      formatted = round_trip("USE FROM other_schema; -- why\n")

      expect_remark_on(formatted, "USE FROM other_schema;", "-- why")
    end

    it "gives each of several clauses its own remark" do
      formatted = round_trip(<<~EXPRESS)
        REFERENCE FROM first_schema; -- one
        REFERENCE FROM second_schema; -- two
      EXPRESS

      expect_remark_on(formatted, "first_schema", "-- one")
      expect_remark_on(formatted, "second_schema", "-- two")
    end

    # An item list makes the clause render over several lines even though it
    # was written on one. The remark trailed the whole clause, so it follows
    # the terminating semicolon, exactly as `END_CASE; -- why` does. Only a
    # remark written on the opener line of a genuinely multi-line source
    # clause would be spliced upwards.
    it "keeps the remark after the terminator when an item list follows" do
      formatted = round_trip("REFERENCE FROM other_schema (a, b); -- why\n")

      expect_remark_on(formatted, "b);", "-- why")
      expect(formatted).not_to include("REFERENCE FROM other_schema -- why")
    end
  end

  # Attaching a remark to a node is not enough on its own: unless the node
  # serializes the collection, the remark renders from a fresh parse and
  # vanishes from a cached one. Interface did not map `untagged_remarks`,
  # so this passed a format and failed a cache round trip.
  describe "an interface remark through a serialization round trip" do
    it "survives being written to YAML and read back" do
      source = <<~EXPRESS
        SCHEMA s;
        REFERENCE FROM other_schema; -- why
        CONSTANT c : BOOLEAN := TRUE; END_CONSTANT;
        END_SCHEMA;
      EXPRESS
      model = Expressir::Express::Parser.from_exp(source)

      reloaded = Expressir::Model::ExpFile.from_yaml(model.to_yaml)

      expect_remark_on(reloaded.to_s, "REFERENCE FROM other_schema;", "-- why")
    end
  end

  describe "remarks below an interface clause" do
    # An own-line remark under a clause introduces whatever comes next; it is
    # not the interface's. Indexing Interface nodes made `nearest_node_to`
    # hand remarks like this to the clause, where nothing renders them, so
    # Interface is excluded from that lookup.
    it "leaves an own-line remark with what follows, not the clause above" do
      formatted = round_trip(<<~EXPRESS)
        REFERENCE FROM other_schema;

        -- introduces the constants
      EXPRESS

      # This asserts only the negative, which is weaker than it looks, so
      # the reason is worth stating: the remark does not survive at all here,
      # and did not before this change either. Schema-level remarks between
      # declarations are a separate, still-open gap. What this pins is that
      # indexing Interface did not make the clause swallow it, which is what
      # `remark_scope?` exists to prevent.
      clause = formatted.lines.find { |l| l.include?("REFERENCE FROM") }
      expect(clause).not_to include("introduces the constants")
    end
  end
end
