# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Presenters
      # Abstract base class for presenting UML elements.
      #
      # Defines the common interface that all element presenters must
      # implement. Provides shared utility methods for formatting.
      #
      # Subclasses must implement: to_text, to_table_row, to_hash
      class ElementPresenter
        attr_reader :element, :repository, :context

        # @param element [Object] The UML element to present
        # @param repository [UmlRepository, nil] Optional repository for
        #   additional context
        # @param context [Hash, nil] Optional context hash
        def initialize(element, repository = nil, context = nil)
          @element = element
          @repository = repository
          @context = context || {}
        end

        protected

        # Generate detailed text view of the element.
        #
        # @return [String] Formatted text representation
        # @raise [NotImplementedError] if not implemented by subclass
        def to_text
          raise NotImplementedError,
                "#{self.class} must implement #to_text"
        end

        # Generate a single row for table display.
        #
        # @return [Hash] Hash with keys: :type, :name, :details, etc.
        # @raise [NotImplementedError] if not implemented by subclass
        def to_table_row
          raise NotImplementedError,
                "#{self.class} must implement #to_table_row"
        end

        # Generate structured hash for JSON/YAML output.
        #
        # @return [Hash] Structured data representation
        # @raise [NotImplementedError] if not implemented by subclass
        def to_hash
          raise NotImplementedError,
                "#{self.class} must implement #to_hash"
        end

        # Format cardinality for display.
        #
        # @param attr [Object] Attribute or property with cardinality
        # @return [String] Formatted cardinality like "[1..1]" or "[0..*]"
        def format_cardinality(attr) # rubocop:disable Metrics/CyclomaticComplexity
          return "" unless attr.respond_to?(:cardinality) &&
            attr.cardinality

          card = attr.cardinality
          min = card.respond_to?(:min) ? (card.min || "0") : "0"
          max = card.respond_to?(:max) ? (card.max || "*") : "*"

          "[#{min}..#{max}]"
        end

        # Truncate text to maximum length.
        #
        # @param text [String, nil] Text to truncate
        # @param max_length [Integer] Maximum length
        # @return [String] Truncated text with "..." if needed
        def truncate(text, max_length = 50)
          return "" if text.nil?
          return text if text.length <= max_length

          "#{text[0...(max_length - 3)]}..."
        end

        # Extract package path from qualified name.
        #
        # @param qualified_name [String] Fully qualified name
        # @return [String] Package path (everything except last component)
        def extract_package_path(qualified_name)
          parts = qualified_name.to_s.split("::")
          parts[0..-2].join("::")
        end
      end
    end
  end
end
