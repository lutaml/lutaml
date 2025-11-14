# frozen_string_literal: true

require_relative "element_presenter"

module Lutaml
  module UmlRepository
    module Presenters
      # Factory for creating appropriate presenter for UML elements.
      #
      # Uses a registry pattern to map element classes to presenter classes.
      # Automatically selects the correct presenter based on element type.
      #
      # @example Creating a presenter
      #   presenter = PresenterFactory.create(class_obj, repository)
      #   puts presenter.to_text
      class PresenterFactory
        @presenters = {}

        class << self
          # Create appropriate presenter for the given element.
          #
          # @param element [Object] UML element to present
          # @param repository [UmlRepository, nil] Optional repository context
          # @param context [Hash, nil] Optional context hash for presenter
          # @return [ElementPresenter] Appropriate presenter instance
          # @raise [ArgumentError] if no presenter registered for element
          #   type
          def create(element, repository = nil, context = nil)
            presenter_class = find_presenter_class(element)
            presenter_class.new(element, repository, context)
          end

          # Register a presenter class for an element class.
          #
          # @param element_class [Class] The UML element class
          # @param presenter_class [Class] The presenter class to use
          def register(element_class, presenter_class)
            @presenters[element_class] = presenter_class
          end

          # Get all registered presenters.
          #
          # @return [Hash] Map of element classes to presenter classes
          def presenters
            @presenters
          end

          private

          # Find presenter class for element.
          #
          # Checks exact class match first, then inheritance chain.
          #
          # @param element [Object] Element to find presenter for
          # @return [Class] Presenter class
          # @raise [ArgumentError] if no presenter found
          def find_presenter_class(element)
            # Check exact class match
            return @presenters[element.class] if
              @presenters.key?(element.class)

            # Check inheritance chain
            element.class.ancestors.each do |ancestor|
              return @presenters[ancestor] if @presenters.key?(ancestor)
            end

            # No presenter found
            raise ArgumentError,
                  "No presenter registered for #{element.class}. " \
                  "Available: #{@presenters.keys.join(', ')}"
          end
        end
      end
    end
  end
end
