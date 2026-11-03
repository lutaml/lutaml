# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Rules that delegate builtin lexical checks to the native engine.
      #
      # The validation job wires its compiled engine context into rules
      # including this module; a rule constructed with an explicit
      # `engine_context:` option keeps that precedence.
      module EngineBacked
        attr_writer :engine_context

        private

        # @return [EngineContext, nil]
        def validation_engine
          @engine_context || @options[:engine_context]
        end
      end
    end
  end
end
