# frozen_string_literal: true

require_relative "element_presenter"
require_relative "presenter_factory"

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML Package elements.
      #
      # Formats package information for different output types:
      # text, table rows, and structured data.
      class PackagePresenter < ElementPresenter
        # Generate detailed text view.
        #
        # @return [String] Multi-line formatted text
        def to_text # rubocop:disable Metrics/AbcSize
          lines = []
          lines << "Package: #{element.name}"
          lines << ("=" * 50)
          lines << ""
          lines << "Name:        #{element.name}"
          if element.respond_to?(:xmi_id)
            lines << "XMI ID:      #{element.xmi_id}"
          end
          lines.join("\n")
        end

        # Generate structured hash.
        #
        # @return [Hash] Structured representation
        def to_hash
          data = {
            type: "Package",
            name: element.name,
          }

          data[:xmi_id] = element.xmi_id if element.respond_to?(:xmi_id)

          data
        end
      end

      # Register with factory
      PresenterFactory.register(Lutaml::Uml::Package, PackagePresenter)
    end
  end
end
