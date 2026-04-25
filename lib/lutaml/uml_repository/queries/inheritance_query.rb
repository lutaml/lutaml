# frozen_string_literal: true

require_relative "base_query"
require_relative "../../uml/qualified_name"

module Lutaml
  module UmlRepository
    module Queries
      # Query service for inheritance operations.
      #
      # Provides methods to navigate class inheritance hierarchies using the
      # inheritance_graph index, which maps parent qualified names to arrays
      # of child qualified names.
      #
      # @example Getting a class's parent
      #   query = InheritanceQuery.new(document, indexes)
      #   parent = query.supertype("ModelRoot::Child")
      #
      # @example Getting all ancestors
      #   ancestors = query.ancestors("ModelRoot::GrandChild")
      #   # => [Parent, GrandParent, ...]
      #
      # @example Getting descendants
      #   descendants = query.descendants("ModelRoot::Parent", max_depth: 2)
      class InheritanceQuery < BaseQuery
        # Get the direct parent class (supertype).
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @return [Lutaml::Uml::Class, nil] The parent class,
        # or nil if no parent
        # @example
        #   parent = query.supertype("ModelRoot::Child")
        #   # Or
        #   parent = query.supertype(child_class)
        def supertype(class_or_qname) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          klass = resolve_class(class_or_qname)
          return nil unless klass
          return nil unless klass.respond_to?(:generalization)
          return nil unless klass.generalization

          parent_name = extract_parent_name(klass.generalization)
          return nil unless parent_name
          # avoid self-references
          return nil if parent_name == klass.name

          # Try to find in qualified_names index
          qname_string = resolve_qname(class_or_qname)
          return nil unless qname_string

          qname = Lutaml::Uml::QualifiedName.new(qname_string)
          package_path = qname.package_path.to_s

          # Try to resolve parent qualified name
          parent_qname = resolve_parent_qualified_name(parent_name,
                                                       package_path)
          return nil unless parent_qname

          indexes[:qualified_names][parent_qname]
        end
        alias_method :find_parent, :supertype

        # Get direct child classes (subtypes).
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @param recursive [Boolean] Whether to include all descendants
        #   (default: false)
        # @return [Array] Array of child class objects
        # @example Direct children only
        #   children = query.subtypes("ModelRoot::Parent", recursive: false)
        #
        # @example All descendants
        #   all_descendants = query.subtypes(
        #   "ModelRoot::Parent", recursive: true)
        def subtypes(class_or_qname, recursive: false)
          qname_string = resolve_qname(class_or_qname)
          return [] unless qname_string

          if recursive
            descendants(class_or_qname)
          else
            direct_subtypes(qname_string)
          end
        end
        alias_method :find_children, :subtypes

        # Get all ancestor classes up to the root.
        #
        # Returns ancestors in order from immediate parent to root.
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @return [Array] Array of ancestor class objects, ordered from nearest
        #   to furthest
        # @example
        #   ancestors = query.ancestors("ModelRoot::GrandChild")
        #   # => [Parent, GrandParent]
        def ancestors(class_or_qname)
          result = []
          current = class_or_qname

          loop do
            parent = supertype(current)
            break unless parent

            result << parent
            current = parent
          end

          result
        end

        # Get all ancestor classes up to the root by class XMI ID.
        #
        # @param class_xmi_id [String] The XMI ID of the class
        # @return [Array] Array of ancestor class objects
        def find_ancestors(class_xmi_id)
          qualified_name, _klass = find_class_by_id(class_xmi_id)
          return [] unless qualified_name

          ancestors(qualified_name)
        end

        # Get all descendant classes.
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @param max_depth [Integer, nil] Maximum depth to traverse (nil for
        #   unlimited)
        # @return [Array] Array of descendant class objects
        # @example
        #   descendants = query.descendants("ModelRoot::Parent", max_depth: 2)
        def descendants(class_or_qname, max_depth: nil)
          qname_string = resolve_qname(class_or_qname)
          return [] unless qname_string

          collect_descendants(qname_string, max_depth, 0)
        end

        # Resolve a class or qualified name to a class object.
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @return [Lutaml::Uml::Class, nil] The class object,
        # or nil if not found
        def resolve_class(class_or_qname)
          if class_or_qname.is_a?(String)
            indexes[:qualified_names][class_or_qname]
          else
            class_or_qname
          end
        end

        # Resolve a class or qualified name to a qualified name string.
        #
        # @param class_or_qname [Lutaml::Uml::Class, String] The class object
        #   or qualified name string
        # @return [String, nil] The qualified name string, or nil if not found
        def resolve_qname(class_or_qname)
          if class_or_qname.is_a?(String) &&
              indexes[:qualified_names].key?(class_or_qname)
            return class_or_qname
          end

          # Search for the class in the index
          qname, _klass = indexes[:qualified_names].find do |_name, entity|
            entity == class_or_qname
          end

          qname.nil? ? nil : qname
        end

        # Build inheritance tree for a class.
        #
        # @param class_or_id [Lutaml::Uml::Class, String] The class object,
        #   qualified name, or xmi_id
        # @return [Hash, nil] Tree structure with :class and :children keys
        def inheritance_tree(class_or_id)
          klass = resolve_by_id_or_qname(class_or_id)
          return nil unless klass

          qname = resolve_qname(klass)
          return nil unless qname

          child_qnames = indexes[:inheritance_graph][qname] || []
          child_trees = child_qnames.filter_map do |child_qname|
            inheritance_tree(child_qname)
          end

          {
            class: klass,
            children: child_trees,
          }
        end

        # Check if a class has circular inheritance.
        #
        # @param class_or_id [Lutaml::Uml::Class, String] The class object,
        #   qualified name, or xmi_id
        # @return [Boolean] true if circular inheritance detected
        def has_circular_inheritance?(class_or_id, visited: Set.new)
          qname = if class_or_id.is_a?(String) &&
              indexes[:qualified_names].key?(class_or_id)
                    class_or_id
                  else
                    resolve_qname(class_or_id)
                  end
          return false unless qname

          return true if visited.include?(qname)

          visited.add(qname)
          child_qnames = indexes[:inheritance_graph][qname] || []
          child_qnames.any? do |child_qname|
            has_circular_inheritance?(child_qname, visited: visited.dup)
          end
        end

        private

        # Resolve a class by xmi_id or qualified name
        #
        # @param class_or_id [String] Qualified name or xmi_id
        # @return [Lutaml::Uml::Class, nil] The resolved class
        def resolve_by_id_or_qname(class_or_id)
          # Try as qualified name first
          klass = indexes[:qualified_names][class_or_id]
          return klass if klass

          # Try as xmi_id - search in qualified_names
          indexes[:qualified_names].each_value do |entity|
            next unless entity.respond_to?(:xmi_id)

            return entity if entity.xmi_id == class_or_id
          end

          nil
        end

        # Get direct subtypes of a class
        #
        # @param qname_string [String] Qualified name of the parent class
        # @return [Array] Array of child class objects
        def direct_subtypes(qname_string)
          child_qnames = indexes[:inheritance_graph][qname_string]
          return [] unless child_qnames

          child_qnames.filter_map do |child_qname|
            indexes[:qualified_names][child_qname]
          end
        end

        # Recursively collect descendants
        #
        # @param qname_string [String] Qualified name of the parent class
        # @param max_depth [Integer, nil] Maximum depth to traverse
        # @param current_depth [Integer] Current depth
        # @return [Array] Array of descendant class objects
        def collect_descendants(qname_string, max_depth, current_depth) # rubocop:disable Metrics/MethodLength
          return [] if max_depth && current_depth >= max_depth

          children = direct_subtypes(qname_string)
          result = children.dup

          children.each do |child|
            child_qname = resolve_qname(child)
            next unless child_qname

            grandchildren = collect_descendants(child_qname, max_depth,
                                                current_depth + 1)
            result.concat(grandchildren)
          end

          result
        end

        # Extract parent name from generalization object
        #
        # @param generalization [Lutaml::Uml::Generalization]
        # Generalization object
        # @return [String, nil] Parent class name
        def extract_parent_name(generalization) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
          return nil unless generalization

          # Check for general attribute (could be a string or object)
          if generalization.respond_to?(:general)
            parent = generalization.general
            return parent.name if parent.respond_to?(:name)
            return parent.to_s if parent
          end

          # Check for name attribute directly
          if generalization.respond_to?(:name) && generalization.name
            return generalization.name
          end

          nil
        end

        # Resolve a class name to its qualified name
        #
        # @param name [String] Class name to resolve
        # @param current_package_path [String] Current package context
        # @return [String, nil] Resolved qualified name
        def resolve_parent_qualified_name(name, current_package_path)
          # If name contains "::", it might already be qualified
          return name if indexes[:qualified_names].key?(name)

          # Try in current package
          local_qname = "#{current_package_path}::#{name}"
          return local_qname if indexes[:qualified_names].key?(local_qname)

          # Try to find in all qualified names (simple name match)
          indexes[:qualified_names].each_key do |qname|
            return qname if qname.end_with?("::#{name}")
          end

          nil
        end
      end
    end
  end
end
