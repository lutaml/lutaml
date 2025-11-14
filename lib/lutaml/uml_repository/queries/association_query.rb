# frozen_string_literal: true

require_relative "base_query"
require_relative "inheritance_query"

module Lutaml
  module UmlRepository
    module Queries
      # Query service for association operations.
      #
      # Provides methods to find associations related to classes. Associations
      # can be owned by classes or defined at the document level.
      #
      # @example Finding all associations for a class
      #   query = AssociationQuery.new(document, indexes)
      #   associations = query.find_for_class("ModelRoot::Building")
      #
      # @example Finding owned associations only
      #   associations = query.find_for_class(klass, owned_only: true)
      #
      # @example Finding associations in a specific direction
      #   associations = query.find_for_class(klass, direction: :source)
      class AssociationQuery < BaseQuery
        # Find associations for a specific class.
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @param options [Hash] Query options
        # @option options [Boolean] :owned_only Return only associations owned
        #   by the class (default: false)
        # @option options [Boolean] :navigable_only Return only navigable
        #   associations (default: false)
        # @option options [Symbol] :direction Filter by direction - :source
        #   (class is owner_end), :target (class is member_end), or :both
        #   (default: :both)
        # @return [Array<Lutaml::Uml::Association>] Array of association objects
        # @example
        #   # Get all associations
        #   all = query.find_for_class("ModelRoot::Building")
        #
        #   # Get only owned associations
        #   owned = query.find_for_class("ModelRoot::Building", owned_only: true)
        #
        #   # Get associations where class is the source
        #   sources = query.find_for_class("ModelRoot::Building", direction: :source)
        def find_for_class(class_or_qname, options = {})
          owned_only = options[:owned_only] || false
          navigable_only = options[:navigable_only] || false
          direction = options[:direction] || :both

          klass = resolve_class(class_or_qname)
          return [] unless klass

          class_name = klass.name
          results = []

          # Get owned associations from the class itself
          if klass.respond_to?(:associations) && klass.associations
            results.concat(klass.associations)
          end

          # Get associations from document level unless owned_only
          if !owned_only && document.respond_to?(:associations) && document.associations
            document_associations = document.associations.select do |assoc|
              match_association?(assoc, class_name, direction)
            end
            results.concat(document_associations)
          end

          # Filter navigable if requested
          if navigable_only
            results.select! { |assoc| navigable?(assoc) }
          end

          results.uniq
        end

        private

        # Resolve a class or qualified name to a class object
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @return [Lutaml::Uml::Class, nil] The class object, or nil if not found
        def resolve_class(class_or_qname)
          if class_or_qname.is_a?(String)
            indexes[:qualified_names][class_or_qname]
          else
            class_or_qname
          end
        end

        # Check if an association matches the class name and direction
        #
        # @param assoc [Lutaml::Uml::Association] The association to check
        # @param class_name [String] The class name to match
        # @param direction [Symbol] The direction filter (:source, :target, :both)
        # @return [Boolean] true if the association matches
        def match_association?(assoc, class_name, direction)
          case direction
          when :source
            # Class is the owner_end (source)
            assoc.owner_end == class_name
          when :target
            # Class is the member_end (target)
            assoc.member_end == class_name
          when :both
            # Class is either end
            assoc.owner_end == class_name || assoc.member_end == class_name
          else
            false
          end
        end

        # Check if an association is navigable
        #
        # An association is considered navigable if it has attribute names
        # defined for navigation.
        #
        # @param assoc [Lutaml::Uml::Association] The association to check
        # @return [Boolean] true if navigable
        def navigable?(assoc)
          # An association is navigable if it has member_end_attribute_name
          # or owner_end_attribute_name defined
          !assoc.member_end_attribute_name.nil? || !assoc.owner_end_attribute_name.nil?
        end
      end
    end
  end
end
