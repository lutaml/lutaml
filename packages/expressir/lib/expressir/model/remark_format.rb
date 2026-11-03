# frozen_string_literal: true

module Expressir
  module Model
    # Single source of truth for the remark-format vocabulary.
    #
    # Reference: ISO 10303-11 §7.1.6 defines exactly two remark forms:
    # the tail remark (`-- ... \n`) and the embedded remark (`(* ... *)`).
    # Both the model (RemarkInfo) and the express-side scanner/attacher
    # reference these constants instead of bare string literals, so a
    # rename or extension lands in one place.
    module RemarkFormat
      TAIL = "tail"
      EMBEDDED = "embedded"
    end
  end
end
