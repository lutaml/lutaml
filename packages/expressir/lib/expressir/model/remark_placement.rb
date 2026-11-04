# frozen_string_literal: true

module Expressir
  module Model
    # Single source of truth for where a remark sits relative to the model
    # element that owns it.
    #
    # The parser discards comments, so attachment reconstructs their position
    # from source lines. Placement records that reconstruction, letting the
    # formatter put the remark back where it was written:
    #
    # - LEADING — on its own line(s) directly above the owning statement.
    # - TRAILING — on its own line(s) at the end of a body, before the closing
    #   keyword. The owner is the body's owner, and RemarkInfo#region names
    #   which body: an IF owns two, and they close at different keywords.
    # - INLINE — on the same line as the owning statement, after its text.
    #   Emitted after the whole statement, which for a single-line one is the
    #   line it was written on. RemarkInfo#region separates the other case:
    #   OPENER_REGION means the remark trailed the opening line of a statement
    #   spanning several lines, as in `IF x THEN -- why`, and belongs back on
    #   that opener rather than after the closing keyword.
    #
    # `nil` means the remark was attached by a legacy path, or predates
    # placement tracking. Those keep their historical emission and must not
    # be rendered by placement-aware emitters.
    module RemarkPlacement
      LEADING = "leading"
      TRAILING = "trailing"
      INLINE = "inline"

      # Region of an INLINE remark that trailed a compound statement's opener.
      OPENER_REGION = "opener"

      # Regions of INLINE remarks that trailed a mid-construct keyword line —
      # `ELSE -- why` or `OTHERWISE : -- why`. The owning construct is the
      # enclosing IF / CASE, and the remark belongs back after that keyword,
      # not after the construct's closing END_.
      ELSE_REGION = "else"
      OTHERWISE_REGION = "otherwise"
    end
  end
end
