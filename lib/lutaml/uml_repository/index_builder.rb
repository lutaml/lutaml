# frozen_string_literal: true

require_relative "../uml/package_path"
require_relative "../uml/qualified_name"
require_relative "index_builders/package_index"
require_relative "index_builders/class_index"
require_relative "index_builders/association_index"

module Lutaml
  module UmlRepository
    # IndexBuilder builds fast lookup indexes from a Lutaml::Uml::Document
    #
    # This class creates immutable hash indexes that enable O(1) lookups for:
    # - Package paths (e.g., "ModelRoot::i-UR::urf")
    # - Qualified names (e.g., "ModelRoot::i-UR::urf::Building")
    # - Stereotypes (e.g., "featureType" => [Class, Class, ...])
    # - Inheritance graph (parent_qname => [child_qname, ...])
    # - Diagram index (package_id => [Diagram, ...])
    # - Package to path mapping (package_id => path)
    # - Class to qualified name mapping (class_id => qualified_name)
    # - Classes (class_id => Class)
    # - Associations (association_id => Association)
    #
    # All indexes are frozen to ensure immutability.
    #
    # @example Building all indexes from a document
    #   indexes = IndexBuilder.build_all(document)
    #   package = indexes[:package_paths]["ModelRoot::i-UR"]
    #   klass = indexes[:qualified_names]["ModelRoot::i-UR::Building"]
    class IndexBuilder
      ROOT_PACKAGE_NAME = "ModelRoot"

      # Build all indexes from a UML document
      #
      # @param document [Lutaml::Uml::Document] The UML document to index
      # @return [Hash] A frozen hash containing all indexes with keys:
      #   - :package_paths - Maps package paths to Package objects
      #   - :qualified_names - Maps qualified names to
      #     Class/DataType/Enum objects
      #   - :stereotypes - Groups classes by stereotype
      #   - :inheritance_graph - Maps parent qualified names to child
      #     qualified names
      #   - :diagram_index - Maps package IDs/paths to Diagram objects
      #   - :package_to_path - Maps package XMI IDs to paths
      #   - :class_to_qname - Maps class XMI IDs to qualified names
      #   - :classes - Maps class XMI IDs to Class objects
      #   - :associations - Maps association XMI IDs to Association objects
      def self.build_all(document)
        new(document).build_all
      end

      # Build package paths index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @return [Hash] Frozen hash mapping package paths to Package objects
      def self.build_package_paths(document)
        builder = new(document)
        builder.build_package_path_index
        builder.instance_variable_get(:@package_paths).freeze
      end

      def self.build_package_to_path(document)
        builder = new(document)
        builder.build_package_path_index
        builder.instance_variable_get(:@package_to_path).freeze
      end

      # Build qualified names index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @return [Hash] Frozen hash mapping qualified names to Class objects
      def self.build_qualified_names(document)
        builder = new(document)
        builder.build_qualified_name_index
        builder.instance_variable_get(:@qualified_names).freeze
      end

      def self.build_class_to_qname(document)
        builder = new(document)
        builder.build_qualified_name_index
        builder.instance_variable_get(:@class_to_qname).freeze
      end

      def self.build_classes(document)
        builder = new(document)
        builder.build_qualified_name_index
        builder.instance_variable_get(:@classes).freeze
      end

      def self.build_associations(document)
        builder = new(document)
        # build_association_index needs @qualified_names to collect
        # class-level associations
        builder.build_qualified_name_index
        builder.build_association_index
        builder.instance_variable_get(:@associations).freeze
      end

      # Build stereotypes index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @return [Hash] Frozen hash grouping classes by stereotype
      def self.build_stereotypes(document)
        builder = new(document)
        builder.build_stereotype_index
        builder.instance_variable_get(:@stereotypes).freeze
      end

      # Build inheritance graph index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @param indexes [Hash, nil] Existing indexes (requires :qualified_names)
      # @return [Hash] Frozen hash mapping parent qnames to child qnames
      def self.build_inheritance_graph(document, indexes)
        builder = new(document)
        # If qualified_names index is provided, use it
        if indexes && indexes[:qualified_names]
          builder.instance_variable_set(:@qualified_names,
                                        indexes[:qualified_names])
        else
          builder.build_qualified_name_index
        end
        builder.build_inheritance_graph_index
        builder.instance_variable_get(:@inheritance_graph).freeze
      end

      # Build diagram index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @param indexes [Hash, nil] Existing indexes (requires :package_paths)
      # @return [Hash] Frozen hash mapping package IDs to Diagram objects
      def self.build_diagram_index(document, indexes)
        builder = new(document)
        # If package_paths index is provided, use it
        if indexes && indexes[:package_paths]
          builder.instance_variable_set(:@package_paths,
                                        indexes[:package_paths])
        else
          builder.build_package_path_index
        end
        builder.build_diagram_index
        builder.instance_variable_get(:@diagram_index).freeze
      end

      def initialize(document)
        @document = document
        @package_paths = {}
        @qualified_names = {}
        @stereotypes = {}
        @inheritance_graph = {}
        @diagram_index = {}
        @package_to_path = {}
        @class_to_qname = {}
        @classes = {}
        @associations = {}
        @simple_name_to_qnames = {}
        @package_to_classes = {}
      end

      # Build all indexes and return them as a frozen hash
      #
      # @return [Hash] Frozen hash containing all indexes
      def build_all # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        build_package_path_index
        build_qualified_name_index
        build_stereotype_index
        build_inheritance_graph_index
        build_diagram_index
        build_association_index

        {
          package_paths: @package_paths.freeze,
          qualified_names: @qualified_names.freeze,
          stereotypes: @stereotypes.freeze,
          inheritance_graph: @inheritance_graph.freeze,
          diagram_index: @diagram_index.freeze,
          package_to_path: @package_to_path.freeze,
          class_to_qname: @class_to_qname.freeze,
          classes: @classes.freeze,
          associations: @associations.freeze,
          package_to_classes: plain_hash(@package_to_classes).freeze,
        }.freeze
      end

      # Build the diagram index
      #
      # Creates a hash mapping package IDs/paths to arrays of Diagram objects:
      #   "package_id" => [Diagram{}, Diagram{}]
      # @api public
      def build_diagram_index
        # Traverse packages and collect diagrams
        traverse_packages(@document.packages) do |package, path|
          next unless package.diagrams && !package.diagrams.empty?

          # Index by package ID if available, otherwise by path
          key = package.xmi_id || path
          @diagram_index[key] ||= []
          @diagram_index[key].concat(package.diagrams)
        end
      end

      private

      # Convert a hash with default proc to a plain hash (Marshal-safe)
      # @param hash [Hash] Hash possibly with default proc
      # @return [Hash] Plain hash without default proc
      def plain_hash(hash_with_default)
        hash_with_default.each_with_object({}) { |(k, v), h| h[k] = v }
      end
    end
  end
end
