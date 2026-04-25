# frozen_string_literal: true

module Lutaml
  module UmlRepository
    class IndexBuilder
      def build_association_index # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        # Collect document-level associations (XMI format)
        @document.associations&.each do |assoc|
          next unless assoc.xmi_id

          @associations[assoc.xmi_id] = assoc
        end

        # Collect class-level associations (QEA/EA format)
        # Note: This requires qualified_names index to be built first
        @qualified_names.each_value do |klass|
          next unless klass.respond_to?(:associations) && klass.associations

          klass.associations.each do |assoc|
            next unless assoc.xmi_id

            # Avoid duplicates - only add if not already present
            @associations[assoc.xmi_id] ||= assoc
          end
        end
      end

      # Build the inheritance graph index
      #
      # Creates a hash mapping parent qualified names to arrays of
      # child qualified names:
      #   "ModelRoot::Parent" => ["ModelRoot::Child1", "ModelRoot::Child2"]
      # @api public
      def build_inheritance_graph_index
        # Process top-level classes
        if @document.classes
          process_generalizations(@document.classes,
                                  ROOT_PACKAGE_NAME)
        end

        # Process classes in packages
        traverse_packages(@document.packages,
                          parent_path: ROOT_PACKAGE_NAME) do |package, path|
          process_generalizations(package.classes, path) if package.classes
        end
      end

      # Process generalization relationships to build inheritance graph
      #
      # @param classes [Array<Lutaml::Uml::Class>] Classes to process
      # @param package_path [String] Package path for these classes
      def process_generalizations(classes, package_path) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        return unless classes

        classes.each do |klass|
          next unless klass.name

          child_qname = "#{package_path}::#{klass.name}"

          # Handle generalization attribute
          if klass.generalization
            parent_name = extract_parent_name(klass.generalization)
            if parent_name
              parent_qname = resolve_qualified_name(parent_name, package_path)
              if parent_qname && child_qname != parent_qname
                @inheritance_graph[parent_qname] ||= []
                @inheritance_graph[parent_qname] << child_qname
              end
            end
          end

          # Handle inheritance associations
          next unless klass.associations

          klass.associations.each do |assoc|
            next unless assoc.respond_to?(:member_end_type)
            next unless assoc.member_end_type == "inheritance"

            parent_name = assoc.member_end
            next unless parent_name

            parent_name = parent_name.name if parent_name.respond_to?(:name)
            next unless parent_name.is_a?(String) && !parent_name.empty?

            parent_qname = resolve_qualified_name(parent_name, package_path)
            next unless parent_qname
            next if child_qname == parent_qname

            @inheritance_graph[parent_qname] ||= []
            @inheritance_graph[parent_qname] << child_qname
          end
        end
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
      # This is a simplified resolution that checks:
      # 1. Same package
      # 2. Already qualified name in index
      #
      # @param name [String] Class name to resolve
      # @param current_package_path [String] Current package context
      # @return [String, nil] Resolved qualified name
      def resolve_qualified_name(name, current_package_path)
        # If name contains "::", it might already be qualified
        return name if @qualified_names.key?(name)

        # Try in current package
        local_qname = "#{current_package_path}::#{name}"
        return local_qname if @qualified_names.key?(local_qname)

        # O(1) lookup using reverse index instead of O(n) scan
        candidates = @simple_name_to_qnames[name]
        candidates&.first
      end
    end
  end
end
