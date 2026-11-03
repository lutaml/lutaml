# frozen_string_literal: true

module Lutaml
  module Xsd
    # Analyzes type inheritance hierarchies
    # Single responsibility: build and analyze type hierarchy trees
    # Separates analysis logic from presentation (visualization formats)
    class TypeHierarchyAnalyzer
      attr_reader :repository

      def initialize(repository)
        @repository = repository
      end

      # Analyze complete hierarchy for a type
      # @param qualified_name [String] The qualified type name (e.g., "gml:AbstractFeatureType")
      # @param depth [Integer] Maximum depth to traverse (default: 10)
      # @return [Hash, nil] Hierarchy analysis result or nil if type not found
      def analyze(qualified_name, depth: 10)
        type_result = @repository.find_type(qualified_name)
        return nil unless type_result.resolved?

        root_node = build_tree(qualified_name, depth)

        {
          root: qualified_name,
          namespace: type_result.namespace,
          local_name: type_result.local_name,
          type_category: determine_type_category(type_result.definition),
          ancestors: find_ancestors(type_result.definition, depth),
          descendants: find_descendants(qualified_name, depth),
          tree: root_node.to_h,
          formats: {
            mermaid: to_mermaid(root_node),
            text: to_text_tree(root_node),
          },
        }
      end

      private

      # Find all ancestor types (base types through extension/restriction)
      # @param definition [Base] The type definition
      # @param depth [Integer] Maximum depth to traverse
      # @param visited [Set] Already visited types (cycle detection)
      # @return [Array<Hash>] List of ancestor types
      def find_ancestors(definition, depth, visited = Set.new)
        return [] if depth <= 0
        return [] if visited.include?(definition.object_id)

        visited.add(definition.object_id)
        ancestors = []

        base_type = extract_base_type(definition)
        return ancestors unless base_type

        # Skip XML Schema built-in types
        return ancestors if /^xsd?:/.match?(base_type)

        # Resolve the base type
        base_result = @repository.find_type(base_type)
        return ancestors unless base_result.resolved?

        # Add this ancestor
        ancestors << {
          qualified_name: base_type,
          namespace: base_result.namespace,
          local_name: base_result.local_name,
          type_category: determine_type_category(base_result.definition),
        }

        # Recursively find ancestors of the base type
        parent_ancestors = find_ancestors(base_result.definition, depth - 1,
                                          visited)
        ancestors.concat(parent_ancestors)

        ancestors
      end

      # Find all descendant types (types that extend/restrict this type)
      # @param qualified_name [String] The qualified type name
      # @param depth [Integer] Maximum depth to traverse
      # @return [Array<Hash>] List of descendant types
      def find_descendants(qualified_name, depth)
        return [] if depth <= 0

        descendants = []
        all_types = @repository.instance_variable_get(:@type_index).all

        all_types.each_value do |type_info|
          definition = type_info[:definition]
          next unless definition

          base_type = extract_base_type(definition)
          next unless base_type

          # Check if this type extends/restricts our target type
          next unless types_match?(base_type, qualified_name,
                                   type_info[:namespace])

          qname = build_qualified_name(type_info)
          descendants << {
            qualified_name: qname,
            namespace: type_info[:namespace],
            local_name: type_info[:definition]&.name,
            type_category: type_info[:type],
          }

          # Recursively find descendants
          child_descendants = find_descendants(qname, depth - 1)
          descendants.concat(child_descendants)
        end

        descendants
      end

      # Build hierarchical tree structure
      # @param qualified_name [String] The qualified type name
      # @param depth [Integer] Maximum depth to traverse
      # @param visited [Set] Already visited types (cycle detection)
      # @return [TypeHierarchyNode, nil] Root node of the tree
      def build_tree(qualified_name, depth, visited = Set.new)
        return nil if depth <= 0
        return nil if visited.include?(qualified_name)

        visited.add(qualified_name)

        type_result = @repository.find_type(qualified_name)
        return nil unless type_result.resolved?

        category = determine_type_category(type_result.definition)
        node = TypeHierarchyNode.new(qualified_name, category: category,
                                                     depth: 0)

        # Find ancestors (base types)
        base_type = extract_base_type(type_result.definition)
        if base_type && base_type !~ /^xsd?:/
          ancestor_node = build_tree(base_type, depth - 1, visited)
          node.add_ancestor(ancestor_node) if ancestor_node
        end

        # Find descendants (derived types)
        all_types = @repository.instance_variable_get(:@type_index).all
        all_types.each_value do |type_info|
          definition = type_info[:definition]
          next unless definition

          def_base_type = extract_base_type(definition)
          next unless def_base_type

          next unless types_match?(def_base_type, qualified_name,
                                   type_info[:namespace])

          child_qname = build_qualified_name(type_info)
          next if visited.include?(child_qname)

          child_node = build_tree(child_qname, depth - 1, visited)
          node.add_descendant(child_node) if child_node
        end

        node
      end

      # Generate Mermaid diagram syntax
      # @param node [TypeHierarchyNode] The root node
      # @return [String] Mermaid diagram syntax
      def to_mermaid(node)
        lines = ["graph TD"]
        node_id_map = {}
        counter = 0

        # Helper to generate unique node IDs
        generate_node_id = lambda do |qname|
          node_id_map[qname] ||= begin
            counter += 1
            "N#{counter}"
          end
        end

        # Recursive helper to add nodes and edges
        add_to_diagram = lambda do |current_node, visited = Set.new|
          return if visited.include?(current_node.qualified_name)

          visited.add(current_node.qualified_name)

          current_id = generate_node_id.call(current_node.qualified_name)
          label = "#{current_node.qualified_name}<br/>#{current_node.category}"
          lines << "  #{current_id}[\"#{label}\"]"

          # Add ancestors
          current_node.ancestors.each do |ancestor|
            ancestor_id = generate_node_id.call(ancestor.qualified_name)
            lines << "  #{ancestor_id} --> #{current_id}"
            add_to_diagram.call(ancestor, visited)
          end

          # Add descendants
          current_node.descendants.each do |descendant|
            descendant_id = generate_node_id.call(descendant.qualified_name)
            lines << "  #{current_id} --> #{descendant_id}"
            add_to_diagram.call(descendant, visited)
          end
        end

        add_to_diagram.call(node)
        lines.join("\n")
      end

      # Generate text tree with indentation
      # @param node [TypeHierarchyNode] The root node
      # @param indent [String] Current indentation
      # @param visited [Set] Already visited nodes (cycle detection)
      # @return [String] Text tree representation
      def to_text_tree(node, indent = "", visited = Set.new)
        return "" if visited.include?(node.qualified_name)

        visited.add(node.qualified_name)

        lines = []

        # Show ancestors first (base types)
        unless node.ancestors.empty?
          lines << "#{indent}Ancestors (base types):"
          node.ancestors.each do |ancestor|
            lines << "#{indent}  ↑ #{ancestor.qualified_name} (#{ancestor.category})"
            lines << to_text_tree(ancestor, "#{indent}    ", visited)
          end
          lines << ""
        end

        # Show current node
        lines << "#{indent}#{node.qualified_name} (#{node.category})"

        # Show descendants (derived types)
        unless node.descendants.empty?
          lines << "#{indent}Descendants (derived types):"
          node.descendants.each do |descendant|
            lines << "#{indent}  ↓ #{descendant.qualified_name} (#{descendant.category})"
            lines << to_text_tree(descendant, "#{indent}    ", visited)
          end
        end

        lines.join("\n")
      end

      # Extract base type from a type definition
      # @param definition [Base] The type definition
      # @return [String, nil] The base type qualified name
      def extract_base_type(definition)
        # ComplexType with complexContent/extension
        if definition.complex_content
          return definition.complex_content.extension.base if definition.complex_content.extension
          return definition.complex_content.restriction.base if definition.complex_content.restriction
        end

        # ComplexType with simpleContent/extension
        if definition.simple_content
          return definition.simple_content.extension.base if definition.simple_content.extension
          return definition.simple_content.restriction.base if definition.simple_content.restriction
        end

        # SimpleType with restriction
        return definition.restriction.base if definition.restriction

        nil
      end

      # Check if two type names match (accounting for different prefixes)
      # @param type1 [String] First type name
      # @param type2 [String] Second type name
      # @param namespace [String, nil] Namespace URI for resolution
      # @return [Boolean] True if types match
      def types_match?(type1, type2, _namespace = nil)
        # Try direct match first
        return true if type1 == type2

        # Parse both types
        parsed1 = @repository.parse_qualified_name(type1)
        parsed2 = @repository.parse_qualified_name(type2)

        return false unless parsed1 && parsed2

        # Compare namespaces and local names
        parsed1[:namespace] == parsed2[:namespace] &&
          parsed1[:local_name] == parsed2[:local_name]
      end

      # Build qualified name from type info
      # @param type_info [Hash] Type information from index
      # @return [String] Qualified name
      def build_qualified_name(type_info)
        namespace = type_info[:namespace]
        name = type_info[:definition]&.name
        return name unless namespace

        prefix = @repository.namespace_to_prefix(namespace)
        prefix ? "#{prefix}:#{name}" : name
      end

      # Determine type category from definition
      # @param definition [Base] The type definition
      # @return [Symbol] Type category
      def determine_type_category(definition)
        return :complex_type if definition.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
        return :simple_type if definition.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType)
        return :element if definition.is_a?(Lutaml::Xml::Schema::Xsd::Element)
        return :attribute_group if definition.is_a?(Lutaml::Xml::Schema::Xsd::AttributeGroup)
        return :group if definition.is_a?(Lutaml::Xml::Schema::Xsd::Group)

        :unknown
      end
    end

    # Value object representing a node in type hierarchy
    # Immutable once created, with ancestors and descendants
    class TypeHierarchyNode
      attr_reader :qualified_name, :category, :depth, :ancestors, :descendants

      def initialize(qualified_name, category:, depth: 0)
        @qualified_name = qualified_name
        @category = category
        @depth = depth
        @ancestors = []
        @descendants = []
      end

      # Add an ancestor node (base type)
      # @param node [TypeHierarchyNode] The ancestor node
      def add_ancestor(node)
        @ancestors << node unless @ancestors.include?(node)
      end

      # Add a descendant node (derived type)
      # @param node [TypeHierarchyNode] The descendant node
      def add_descendant(node)
        @descendants << node unless @descendants.include?(node)
      end

      # Convert to hash for serialization
      # @return [Hash] Hash representation
      def to_h
        {
          qualified_name: @qualified_name,
          category: @category,
          depth: @depth,
          ancestors: @ancestors.map(&:to_h),
          descendants: @descendants.map(&:to_h),
        }
      end
    end
  end
end
