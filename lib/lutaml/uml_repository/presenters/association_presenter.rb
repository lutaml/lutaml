# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Presenters
      # Presenter for UML Association elements.
      #
      # Formats association information including source, target, and roles.
      class AssociationPresenter < ElementPresenter
        def initialize(element, repository = nil, context = nil)
          super
        end

        def to_text # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          lines = []
          lines << "Association: #{element.name || '(unnamed)'}"
          lines << ("=" * 50)
          lines << ""
          lines << "Name:          #{element.name || '(unnamed)'}"
          if element.xmi_id
            lines << "XMI ID:        #{element.xmi_id}"
          end
          lines << ""
          lines << "Source:        #{source_display}"
          lines << "Target:        #{target_display}"
          lines.join("\n")
        end

        def to_table_row
          {
            type: "Association",
            name: element.name || "(unnamed)",
            details: "#{source_display} → #{target_display}",
          }
        end

        def to_hash
          data = {
            type: "Association",
            name: element.name,
            source: source_display,
            target: target_display,
          }

          data[:xmi_id] = element.xmi_id if element.xmi_id

          data
        end

        private

        def source_display
          @context["source"] || @context[:source] ||
            element.owner_end || "Unknown"
        end

        def target_display # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          # Check string key first (from search),
          # then symbol key (from show command)
          if @context["target"] || @context[:target]
            @context["target"] || @context[:target]
          elsif element.member_end
            member_end = element.member_end.first
            if member_end.is_a?(Hash)
              member_end[:xmi_type] || "Unknown"
            else
              member_end.to_s
            end
          else
            "Unknown"
          end
        end
      end

      # Register with factory
      PresenterFactory.register(Lutaml::Uml::Association, AssociationPresenter)
    end
  end
end
