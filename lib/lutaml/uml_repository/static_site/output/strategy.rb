# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Output
        # Base class for output strategies (Strategy Pattern).
        #
        # Subclasses implement #render to produce HTML output from
        # a SpaDocument and SpaSearchIndex.
        #
        # @abstract Subclass and implement {#render}
        class Strategy
          def initialize(output_path, config:)
            @output_path = output_path
            @config = config
          end

          # Render output from the given document and search index.
          #
          # @param spa_document [Models::SpaDocument]
          # @param search_index [Models::SpaSearchIndex]
          # @return [String] Path to generated output
          def render(_spa_document, _search_index)
            raise NotImplementedError,
                  "#{self.class} must implement #render"
          end

          private

          attr_reader :output_path, :config
        end
      end
    end
  end
end
