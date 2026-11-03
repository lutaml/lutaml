# frozen_string_literal: true

module Expressir
  # Citable reference artifacts generated from the implementation:
  # the grammar cross-walk and the checker note-id catalog.
  module Reference
    autoload :GrammarCrosswalk, "#{__dir__}/reference/grammar_crosswalk"
    autoload :NoteCatalog, "#{__dir__}/reference/note_catalog"
  end
end
