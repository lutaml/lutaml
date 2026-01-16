# frozen_string_literal: true

require_relative "element_presenter"
require_relative "presenter_factory"

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML Class elements.
      #
      # Formats class information for different output types:
      # text, table rows, and structured data.
      class ClassPresenter < ElementPresenter
        # Generate detailed text view.
        #
        # @return [String] Multi-line formatted text
        def to_text # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          lines = []
          lines << "Class: #{element.name}"
          lines << ("=" * 50)
          lines << ""
          lines << "Name:        #{element.name}"
          lines << "XMI ID:      #{element.xmi_id}" if
            element.xmi_id
          lines << "Stereotype:  #{element.stereotype}" if
            element.stereotype
          lines << "Abstract:    #{element.is_abstract}"
          lines.join("\n")
        end

        # Generate table row data.
        #
        # @return [Hash] Row data with :type, :name, :details keys
        def to_table_row
          {
            type: "Class",
            name: element.name || "(unnamed)",
            details: stereotype_display,
          }
        end

        # Generate structured hash.
        #
        # @return [Hash] Structured representation
        def to_hash # rubocop:disable Metrics/AbcSize
          data = {
            type: "Class",
            name: element.name,
            is_abstract: !!element.is_abstract,
          }

          data[:xmi_id] = element.xmi_id if element.xmi_id
          if element.stereotype
            data[:stereotype] = element.stereotype
          end

          data
        end

        private

        def stereotype_display
          if element.respond_to?(:stereotype) && element.stereotype
            "<<#{element.stereotype}>>"
          else
            ""
          end
        end
      end

      # Register with factory
      PresenterFactory.register(Lutaml::Uml::Class, ClassPresenter)
    end
  end
end
