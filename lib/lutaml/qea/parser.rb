# frozen_string_literal: true

require_relative "../qea"

module Lutaml
  module Qea
    # Parser class provides backward compatibility wrapper for Qea.parse
    #
    # This class exists for compatibility with older code that uses
    # Qea::Parser.parse instead of the newer Qea.parse method.
    #
    # @example Parse a QEA file
    #   document = Lutaml::Qea::Parser.parse("model.qea")
    #   repo = document.to_uml_repository
    #
    # @see Qea.parse
    class Parser
      class << self
        # Parse a QEA file and return UML document
        #
        # This is a backward compatibility wrapper that delegates to Qea.parse
        #
        # @param qea_path [String] Path to the .qea file
        # @param options [Hash] Transformation options
        # @return [Lutaml::Uml::Document] Complete UML document
        #
        # @see Qea.parse
        def parse(qea_path, options = {})
          Qea.parse(qea_path, options)
        end
      end
    end
  end
end
