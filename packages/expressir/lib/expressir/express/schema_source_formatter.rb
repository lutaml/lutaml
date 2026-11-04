# frozen_string_literal: true

module Expressir
  module Express
    # Pre-built Formatter subclass rendering the schema head with
    # hyperlinks: SchemaHeadFormatter + HyperlinkFormatter. Allocated
    # once at load time rather than per call. It backs
    # Schema#source_hyperlinked; Schema#source uses
    # SchemaPlainSourceFormatter, the unlinked counterpart (#255).
    class SchemaSourceFormatter < Formatter
      include SchemaHeadFormatter
      include HyperlinkFormatter
    end
  end
end
