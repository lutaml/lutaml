# frozen_string_literal: true

require "spec_helper"

# Where each remark ends up, as opposed to whether it survives.
#
# A remark can come through a round trip intact and still be wrong. On main,
# two remarks in `function_body_remarks.exp` escape a REPEAT loop and reattach
# to the enclosing statement and function: the text is present, spelled the
# same, and counted, so the conservation spec passes them. This one does not.
#
# Tagged remarks are traced too. They live in a plain string collection on
# the element they bind to rather than in the RemarkInfo list, and reading
# only the latter made this spec pass `remark.exp` while examining none of
# its remarks. That fixture holds 133 tagged tail remarks and one tagged
# embedded remark, hence 134.
#
# The only move allowed is the documented schema-level gap, where a remark
# between declarations is written outside its SCHEMA and a reparse attaches it
# to the file. `escapes` is pinned per fixture so that gap cannot widen, and
# the shape is checked so a remark leaving any other construct fails.
#
# `traced` and `tagged` are floors, not snapshots, and they exist for a
# different reason: an ownership check that reads no remarks passes every
# fixture. That is exactly how the tagged-remark blind spot went unnoticed,
# `remark.exp` reporting no moves while none of its remarks were read.
# Adding a comment to a shared fixture should not fail these; losing coverage
# should.
# The traced and tagged floors dropped by 20 with the GH-363 empty-remark
# guard: each of these fixtures carries 20 `--IPn:` informal-proposition
# declarations whose scanner entries have empty bodies. The propositions
# themselves still attach via create_or_find_informal_proposition; what the
# guard removes is the redundant empty-body remark storage, which the
# formatter never rendered and the trace previously counted.
round_trips = {
  "spec/fixtures/examples/autonomous_vehicle_navigation_schema.exp" =>
    { traced: 9, tagged: 0, escapes: 0 },
  "spec/fixtures/examples/geometry_schema.exp" =>
    { traced: 8, tagged: 0, escapes: 0 },
  "spec/fixtures/examples/nested_functions_test_schema.exp" =>
    { traced: 10, tagged: 0, escapes: 0 },
  # This fixture is a deliberate spread of schema-level remarks: before and
  # after the constant block, before a type, and two outside SCHEMA entirely.
  # One remark still escapes to the file across a round trip; the rest hold.
  "spec/fixtures/examples/tail_remarks_test_schema.exp" =>
    { traced: 33, tagged: 7, escapes: 1 },
  "spec/fixtures/function_body_remarks.exp" =>
    { traced: 13, tagged: 0, escapes: 0 },
  "spec/syntax/remark.exp" =>
    { traced: 134, tagged: 134, escapes: 0 },
  "spec/syntax/syntax.exp" =>
    { traced: 22, tagged: 0, escapes: 0 },
}.freeze

RSpec.describe Expressir::Express::Formatter do
  let(:ownership) { Expressir::RemarkOwnership }

  describe "remark ownership" do
    round_trips.each do |path, expected|
      it "keeps every surviving remark of #{File.basename(path)} in place" do
        source_model = Expressir::Express::Parser.from_file(path)
        reparsed_model = Expressir::Express::Parser.from_exp(
          source_model.to_s,
        )

        traced = Expressir::RemarkOwnership::Trace.of(source_model)
        moved = ownership.moved(
          traced, Expressir::RemarkOwnership::Trace.of(reparsed_model)
        )

        expect(traced.size).to be >= expected[:traced]
        expect(traced.count(&:tagged))
          .to be >= expected[:tagged]
        expect(moved.size).to eq(expected[:escapes])
        expect(moved.reject { |_, move| ownership.schema_escape?(move) })
          .to eq({})
      end
    end
  end

  # Placement is the defect class that keeps shipping here, and until this
  # example existed it was checked only on the hand-written fixtures above.
  # The production schema got conservation and no ownership, and
  # conservation structurally cannot see a misplaced remark: it compares
  # multisets, so a remark that escapes a REPEAT loop and reattaches to the
  # enclosing function is still present, still spelled the same, still
  # counted.
  #
  # 637 KB of real EXPRESS, parsed and reparsed, so this costs about two
  # minutes. That is why `rake verify:remarks` runs it and the default suite
  # does not.
  describe "production scale ownership", :production_scale do
    # Copies beyond the ones +right+ also holds, per place. `was` and `now`
    # are place tallies, so this is a count delta rather than a key
    # difference: a copy relocating onto a place that already holds another
    # copy of the same text adds no new key, it only raises that count.
    def copies_beyond(left, right)
      left.each_with_object({}) do |(place, count), rest|
        remainder = count - right.fetch(place, 0)
        rest[place] = remainder if remainder.positive?
      end
    end

    let(:schema_prefix) do
      "ExpFile/schemas[0]Declarations::Schema" \
        "(mathematical_functions_schema)/"
    end

    # Three texts that each have several copies in the schema and lose exactly
    # one through the round trip. How many copies go missing is already pinned
    # in `mathematical_functions_losses.yml`; what is left here is the place
    # count changing, which `moved` reports as a move. None of them is a
    # remark changing owner.
    #
    # The place is pinned, not just the identity. Every copy of these texts
    # sits alone in its own place, so pinning which place loses its copy fixes
    # the surviving set exactly: a different copy departing is a different
    # distribution, and it fails here even though the totals are unchanged.
    #
    # In both the departing copy is the one with no placement recorded.
    # A place is the tuple [path, placement, region]. A third relocation —
    # a `derived` copy on a Return statement — was fixed by the
    # single-attachment change and left this table.
    let(:known_lost_copies) do
      { ["Should be unreachable.", "tail", false] =>
          "functions[14]Declarations::Function(compatible_spaces)/" \
          "statements[13]Statements::If",
        ["Should be unreachable", "tail", false] =>
          "functions[144]Declarations::Function(subspace_of)/" \
          "statements[14]Statements::If" }
        .transform_values { |path| { ["#{schema_prefix}#{path}", nil, nil] => 1 } }
    end

    it "keeps every surviving remark of the production schema in place" do
      path = "spec/syntax/mathematical_functions_schema/" \
             "mathematical_functions_schema.exp"
      source_model = Expressir::Express::Parser.from_file(path)
      reparsed_model = Expressir::Express::Parser.from_exp(source_model.to_s)

      traced = Expressir::RemarkOwnership::Trace.of(source_model)
      reparsed = Expressir::RemarkOwnership::Trace.of(reparsed_model)
      moved = ownership.moved(traced, reparsed)

      # Floors, for the same reason as the table above: an ownership check
      # that reads no remarks reports no moves and passes every assertion
      # below vacuously.
      expect(traced.size).to be >= 1530
      expect(traced.count(&:tagged)).to be >= 1135

      # The reparsed side needs its own floor. `moved` compares only the
      # identities both sides share, so one that vanishes on reparse is not a
      # move and drops out of the comparison entirely. Relocating a remark far
      # enough to lose its identity there left this example green while the
      # reparsed trace quietly fell by one.
      #
      # Far below the source floor, and correctly so: of the 1530 traced in
      # source, 1135 are tagged and the formatter writes almost none of those
      # back, leaving 395 untagged less the recorded losses. The floor sits
      # under the observed 343: the gap to it absorbs the handful of
      # ELSE-line tail remarks whose copies the single-attachment change
      # stopped double-counting (see the losses fixture).
      expect(reparsed.size).to be >= 340

      # `moved` is keyed by identity, so these count distinct remarks, not
      # copies: one identity sitting in nine places is one entry here.
      escapes, others = moved.partition do |_, move|
        ownership.schema_escape?(move)
      end

      # The identity, not just the count. Counting alone would let the known
      # escape be fixed while a different remark started escaping, and
      # conservation would not notice either.
      #
      # Empty since the single-attachment change: the schema-level tail
      # remark that used to escape to the file on reparse now holds. If a
      # remark starts escaping again, this names it.
      expect(escapes.map(&:first)).to eq([])

      # `moved` is keyed by [text, format, tagged], so listing the three
      # identities alone would pin which texts may appear here, not what kind
      # of move they are: relocate the surviving `derived` copy and the key is
      # unchanged, the entry stays allowed, and this passes.
      #
      # So assert the places instead. Nothing may gain a copy, and each text
      # must lose the exact copy recorded above.
      expect(others.map(&:first)).to match_array(known_lost_copies.keys)

      others.each do |identity, (was, now)|
        arrived = copies_beyond(now, was)
        departed = copies_beyond(was, now)

        expect(arrived)
          .to eq({}), "#{identity.first.inspect} gained a copy somewhere"
        expect(departed)
          .to eq(known_lost_copies.fetch(identity)),
              "#{identity.first.inspect} lost a different copy"
      end
    end
  end
end
