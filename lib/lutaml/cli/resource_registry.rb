# frozen_string_literal: true

module Lutaml
  module Cli
    # ResourceRegistry manages element type configurations for CLI commands
    #
    # This registry provides a centralized definition of UML element types
    # and their corresponding repository methods and presenters. It enables
    # extensibility by allowing new element types to be easily added.
    #
    # @example Get configuration for a type
    #   config = ResourceRegistry.config_for(:class)
    #   classes = repository.send(config[:list_method])
    #
    # @example List all available types
    #   ResourceRegistry.types # => [:package, :class, :diagram, ...]
    class ResourceRegistry
      # Element type configurations
      #
      # Each type defines:
      # - list_method: Repository method to list all elements of this type
      # - find_method: Repository method to find a single element
      # - presenter: Presenter class name for formatting output
      # - icon: Display icon for this element type
      # - description: Human-readable description
      TYPES = {
        package: {
          list_method: :list_packages,
          find_method: :find_package,
          presenter: :PackagePresenter,
          icon: "📦",
          description: "Package container",
        },
        class: {
          list_method: :all_classes,
          find_method: :find_class,
          presenter: :ClassPresenter,
          icon: "📋",
          description: "UML Class",
        },
        diagram: {
          list_method: :all_diagrams,
          find_method: :find_diagram,
          presenter: :DiagramPresenter,
          icon: "🖼️",
          description: "UML Diagram",
        },
        attribute: {
          list_method: :all_attributes,
          find_method: :find_attribute,
          presenter: :AttributePresenter,
          icon: "🔹",
          description: "Class attribute",
        },
        association: {
          list_method: :all_associations,
          find_method: :find_association,
          presenter: :AssociationPresenter,
          icon: "🔗",
          description: "Class association",
        },
        enum: {
          list_method: :all_enums,
          find_method: :find_enum,
          presenter: :EnumPresenter,
          icon: "🔢",
          description: "Enumeration",
        },
        datatype: {
          list_method: :all_data_types,
          find_method: :find_data_type,
          presenter: :DataTypePresenter,
          icon: "📊",
          description: "Data type",
        },
      }.freeze

      # Get all registered element types
      #
      # @return [Array<Symbol>] List of type names
      def self.types
        TYPES.keys
      end

      # Get configuration for a specific type
      #
      # @param type [Symbol, String] Element type name
      # @return [Hash, nil] Type configuration or nil if not found
      def self.config_for(type)
        TYPES[type.to_sym]
      end

      # Check if a type is registered
      #
      # @param type [Symbol, String] Element type name
      # @return [Boolean] True if type is registered
      def self.type_registered?(type)
        TYPES.key?(type.to_sym)
      end

      # Get icon for a type
      #
      # @param type [Symbol, String] Element type name
      # @return [String] Icon string or empty string if not found
      def self.icon_for(type)
        config = config_for(type)
        config ? config[:icon] : ""
      end

      # Get description for a type
      #
      # @param type [Symbol, String] Element type name
      # @return [String] Description or empty string if not found
      def self.description_for(type)
        config = config_for(type)
        config ? config[:description] : ""
      end

      # Get all types with their descriptions
      #
      # @return [Hash<Symbol, String>] Map of type to description
      def self.type_descriptions
        TYPES.transform_values { |config| config[:description] }
      end
    end
  end
end
