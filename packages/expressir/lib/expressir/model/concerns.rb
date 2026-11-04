# frozen_string_literal: true

module Expressir
  module Model
    # Marker for types that have an id attribute
    module HasId; end

    # Marker for types that can have remark_items children
    # These are types where RemarkItem children can be created
    module HasRemarkItems; end

    # Marker for types that have a `remarks` string collection
    module HasRemarks; end

    # Marker for scope containers (can contain declarations)
    # Includes schemas, functions, procedures, rules, entities, types, and files
    module ScopeContainer; end

    # Marker for types supporting informal propositions
    module HasInformalPropositions; end

    # Marker for types supporting where rules
    module HasWhereRules; end

    # Marker for types that can own a remark written after them on the same
    # line, as in `x := 1; -- why`. Includers are ModelElements, so they all
    # carry the `untagged_remarks` collection the remark is stored in.
    #
    # Attachment and formatting must agree on this exactly: a type the
    # attacher marks INLINE but the formatter declines to emit loses the
    # remark with nothing to show for it. Both ask this one question.
    #
    # Not the same question as NodePositionIndex#remark_scope?, which decides
    # who owns a remark on a line of its OWN.
    module TakesInlineRemark; end

    # Marker for executable statements (ISO 10303-11 section 13)
    module Statement
      include TakesInlineRemark
    end
  end
end
