# frozen_string_literal: true

module Expressir
  module Express
    # Pre-built Formatter subclass rendering the schema head without
    # hyperlinks — the plain `source` face of Schema (#255).
    class SchemaPlainSourceFormatter < Formatter
      include SchemaHeadFormatter
    end
  end
end
