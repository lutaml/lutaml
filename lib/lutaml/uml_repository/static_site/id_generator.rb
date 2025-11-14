# frozen_string_literal: true

require "digest"

module Lutaml
  module UmlRepository
    module StaticSite
      # Generates stable, short IDs for entities in the JSON data model.
      #
      # Uses MD5 hash of XMI IDs to create consistent, collision-resistant IDs
      # that remain stable across multiple generations.
      #
      # @example
      #   generator = IDGenerator.new
      #   pkg_id = generator.package_id(package)  # => "pkg_a1b2c3d4"
      #   cls_id = generator.class_id(klass)      # => "cls_e5f6g7h8"
      class IDGenerator
        def initialize
          @cache = {}
        end

        # Generate ID for a package
        #
        # @param package [Lutaml::Uml::Package] Package object
        # @return [String] Stable package ID (e.g., "pkg_a1b2c3d4")
        def package_id(package)
          # Use XMI ID for uniqueness - each package has unique XMI ID
          # even if names are identical in different hierarchies
          cache_key = [:package, package.xmi_id]
          @cache[cache_key] ||= generate_id("pkg", package.xmi_id)
        end

        # Generate ID for a class
        #
        # @param klass [Lutaml::Uml::TopElement] Class object
        # @return [String] Stable class ID (e.g., "cls_a1b2c3d4")
        def class_id(klass)
          cache_key = [:class, klass.xmi_id]
          @cache[cache_key] ||= generate_id("cls", klass.xmi_id)
        end

        # Generate ID for an attribute
        #
        # @param attribute [Object] Attribute object
        # @param owner [Object] Owner class
        # @return [String] Stable attribute ID (e.g., "attr_a1b2c3d4")
        def attribute_id(attribute, owner)
          # Use combination of owner ID and attribute name for uniqueness
          composite_key = "#{owner.xmi_id}::#{attribute.name}"
          cache_key = [:attribute, composite_key]
          @cache[cache_key] ||= generate_id("attr", composite_key)
        end

        # Generate ID for an association
        #
        # @param association [Lutaml::Uml::Association] Association object
        # @return [String] Stable association ID (e.g., "assoc_a1b2c3d4")
        def association_id(association)
          cache_key = [:association, association.xmi_id]
          @cache[cache_key] ||= generate_id("assoc", association.xmi_id)
        end

        # Generate ID for an operation
        #
        # @param operation [Object] Operation object
        # @param owner [Object] Owner class
        # @return [String] Stable operation ID (e.g., "op_a1b2c3d4")
        def operation_id(operation, owner)
          composite_key = "#{owner.xmi_id}::#{operation.name}"
          cache_key = [:operation, composite_key]
          @cache[cache_key] ||= generate_id("op", composite_key)
        end

        # Generate ID for a diagram
        #
        # @param diagram [Object] Diagram object
        # @return [String] Stable diagram ID (e.g., "diag_a1b2c3d4")
        def diagram_id(diagram)
          cache_key = [:diagram, diagram.xmi_id]
          @cache[cache_key] ||= generate_id("diag", diagram.xmi_id)
        end

        # Generate ID for a search document
        #
        # @param type [String] Document type (class, attribute, etc.)
        # @param entity_id [String] Entity XMI ID
        # @return [String] Stable document ID (e.g., "doc_class_a1b2c3d4")
        def document_id(type, entity_id)
          cache_key = [:document, type, entity_id]
          @cache[cache_key] ||= generate_id("doc_#{type}", entity_id)
        end

        # Clear the cache (useful for testing)
        #
        # @return [void]
        def clear_cache
          @cache.clear
        end

        private

        # Generate a stable ID from a prefix and key
        #
        # @param prefix [String] ID prefix (e.g., "pkg", "cls")
        # @param key [String] Key to hash (typically XMI ID)
        # @return [String] Generated ID
        def generate_id(prefix, key)
          # Use first 8 characters of MD5 hash for short, stable IDs
          hash = Digest::MD5.hexdigest(key.to_s)[0..7]
          "#{prefix}_#{hash}"
        end
      end
    end
  end
end
