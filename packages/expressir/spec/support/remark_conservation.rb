# frozen_string_literal: true

module Expressir
  # Compares the remarks written in EXPRESS source against the remarks that
  # survive a round trip, so a formatter change cannot silently drop them.
  #
  # Extraction is delegated to the production scanner. A second remark parser
  # written for the specs would be one more thing to get wrong, and that one
  # already handles nested `(* *)` blocks, string literals, and tags.
  module RemarkConservation
    module_function

    # The remarks of one format in EXPRESS source or in formatted output.
    #
    # Both sides of a round trip are read the same way. A remark that starts a
    # line in the source may end a line in the output, so reading the two sides
    # differently would report a move as a loss.
    #
    # The format is a parameter rather than something the caller filters on
    # afterwards. Tail and embedded remarks are separate populations whose
    # round trips fail for different reasons, and comparing them together lets
    # a surviving embedded remark cancel a tail remark that was lost, when the
    # two happen to share a text.
    #
    # An untagged remark with no text carries nothing to conserve, so it is
    # left out. A tagged one still does: `--"x"` and the informal proposition
    # `--IP1:` both bind to an element, and dropping them here would hide
    # their loss behind an empty diff.
    #
    # @param express [String] EXPRESS source or formatted output
    # @param format [String] a Model::RemarkFormat value
    # @return [Array<Express::RemarkScanner::Remark>] in source order
    def remarks(express, format)
      Express::RemarkScanner.new(express).scan
        .select { |remark| remark.format == format }
        .reject { |remark| remark.text.empty? && !remark.tagged? }
    end

    # Texts of the untagged tail remarks.
    #
    # Tagged and untagged remarks are compared separately, and both sides of a
    # round trip are filtered the same way. Filtering only the source side
    # lets a surviving tagged remark cancel out an untagged one that was lost,
    # when the two happen to share a text.
    #
    # @param express [String] EXPRESS source or formatted output
    # @return [Array<String>] duplicates preserved
    def untagged_texts(express)
      remarks(express, Model::RemarkFormat::TAIL).reject(&:tagged?).map(&:text)
    end

    # Tag and text of each tagged tail remark.
    #
    # A tagged remark is identified by both together. The same text under two
    # different tags is two different remarks, and comparing text alone would
    # let one hide the loss of the other.
    #
    # Kept as a pair rather than joined into one string: tags such as `wr:WR1`
    # already contain a colon, so any separator could be forged by a tag and a
    # text that happen to straddle it.
    #
    # @param express [String] EXPRESS source or formatted output
    # @return [Array<Array(String, String)>] duplicates preserved
    def tagged_pairs(express)
      remarks(express, Model::RemarkFormat::TAIL)
        .select(&:tagged?).map { |r| [r.tag, r.text] }
    end

    # Tag and text of every embedded `(* *)` remark, tagged or not.
    #
    # Embedded remarks need one collection where tail remarks need two, for
    # two reasons together:
    #
    # An untagged remark carries a nil tag, so it cannot cancel a tagged one
    # that happens to share its text. The cancellation that {untagged_texts}
    # and {tagged_pairs} are split apart to avoid cannot arise here.
    #
    # And the two tail populations are pinned by different strategies: untagged
    # tail losses are pinned as an exact text map, tagged ones as a total plus
    # an exact survivor list. Embedded remarks use one strategy for both, so
    # one collection says everything the table needs.
    #
    # Do not read the first reason on its own and collapse the tail methods
    # into this shape. That would break the exact untagged-loss table.
    #
    # @param express [String] EXPRESS source or formatted output
    # @return [Array<Array(String, String)>] duplicates preserved, nil tag
    #   for an untagged remark
    def embedded_pairs(express)
      remarks(express, Model::RemarkFormat::EMBEDDED)
        .map { |r| [r.tag, r.text] }
    end

    # Texts present in +expected+ more often than in +actual+.
    #
    # Compared as multisets: losing one of two identical remarks is a loss,
    # which comparing sets would miss. Takes whatever identity the caller
    # chose — a text from {untagged_texts}, a pair from {tagged_pairs}.
    #
    # @param expected [Array<Object>]
    # @param actual [Array<Object>]
    # @return [Hash{Object => Integer}] entry => how many copies went missing
    def lost(expected, actual)
      difference(expected, actual)
    end

    # Texts present in +actual+ more often than in +expected+.
    #
    # @param expected [Array<Object>]
    # @param actual [Array<Object>]
    # @return [Hash{Object => Integer}] entry => how many copies appeared
    def gained(expected, actual)
      difference(actual, expected)
    end

    def difference(left, right)
      counts = left.tally
      right.tally.each { |text, n| counts[text] -= n if counts.key?(text) }
      counts.select { |_, n| n.positive? }
    end

    private_class_method :difference
  end
end
