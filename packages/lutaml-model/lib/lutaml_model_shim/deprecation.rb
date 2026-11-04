# frozen_string_literal: true

module LutamlModelShim
  # One notice per process, silenced by LUTAML_MODEL_SILENCE_DEPRECATION.
  module Deprecation
    MESSAGE = "[DEPRECATION] the `lutaml-model` gem is a transitional alias " \
              "of `lutaml`; depend on `lutaml` instead and keep " \
              "`require \"lutaml/model\"`."

    class << self
      def warn_once
        return if @warned || ENV.key?("LUTAML_MODEL_SILENCE_DEPRECATION")

        @warned = true
        Kernel.warn(MESSAGE)
      end

      def reset!
        @warned = false
      end
    end
  end
end
