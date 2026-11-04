# frozen_string_literal: true

module Expressir
  module Express
    # Pre-built Formatter subclass that mixes in HyperlinkFormatter.
    #
    # Used by ModelElement#source to format an element back into EXPRESS
    # source text with hyperlinks. Allocated once at load time rather than
    # per #source call (which was the previous behaviour — wasteful and
    # rebuilt the format_registry on every call).
    class SourceFormatter < Formatter
      include HyperlinkFormatter
    end
  end
end
