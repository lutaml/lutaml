# frozen_string_literal: true

require_relative "index_builder"

module Lutaml
  module UmlRepository
    # StatisticsCalculator provides comprehensive statistics about a
    # UML repository
    #
    # Calculates detailed metrics including:
    # - Package statistics (depth distribution, sizes)
    # - Class statistics (by stereotype, complexity)
    # - Attribute statistics (type distribution, multiplicity)
    # - Association statistics
    # - Diagram statistics
    # - Model quality metrics
    #
    # @example Getting repository statistics
    #   calculator = StatisticsCalculator.new(document, indexes)
    #   stats = calculator.calculate
    #   puts "Total packages: #{stats[:total_packages]}"
    #   puts "Most complex class: #{stats[:most_complex_classes].first[:name]}"
    class StatisticsCalculator
      # @param document [Lutaml::Uml::Document] The UML document
      # @param indexes [Hash] The repository indexes
      def initialize(document, indexes)
        @document = document
        @indexes = indexes
      end

      # Calculate comprehensive statistics for the repository
      #
      # @return [Hash] Statistics hash with detailed metrics
      def calculate # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        {
          # Basic counts
          total_packages: package_count,
          total_classes: class_count,
          total_data_types: data_type_count,
          total_enums: enum_count,
          total_diagrams: diagram_count,

          # Package statistics
          packages_by_depth: packages_by_depth,
          max_package_depth: max_depth,
          avg_package_depth: avg_package_depth,

          # Class statistics
          classes_by_stereotype: classes_by_stereotype,
          most_complex_classes: most_complex_classes(limit: 10),
          avg_class_complexity: avg_class_complexity,

          # Attribute statistics
          total_attributes: attribute_count,
          attribute_type_distribution: attribute_type_distribution,

          # Association statistics
          total_associations: association_count,

          # Inheritance statistics
          total_inheritance_relationships: inheritance_count,
          max_inheritance_depth: max_inheritance_depth,

          # Model quality metrics
          abstract_class_count: abstract_class_count,
          classes_without_documentation: undocumented_classes_count,
          classes_without_attributes: classes_without_attributes_count,
        }
      end

      private

      # Get total package count
      #
      # @return [Integer] Number of packages
      def package_count
        @indexes[:package_paths].size
      end

      # Get total class count (excluding DataType and Enum)
      #
      # @return [Integer] Number of classes
      def class_count
        @indexes[:qualified_names].count { |_, obj| obj.is_a?(Lutaml::Uml::Class) }
      end

      # Get total data type count
      #
      # @return [Integer] Number of data types
      def data_type_count
        @indexes[:qualified_names].count { |_, obj| obj.is_a?(Lutaml::Uml::DataType) }
      end

      # Get total enum count
      #
      # @return [Integer] Number of enumerations
      def enum_count
        @indexes[:qualified_names].count { |_, obj| obj.is_a?(Lutaml::Uml::Enum) }
      end

      # Get total diagram count
      #
      # @return [Integer] Number of diagrams
      def diagram_count
        @indexes[:diagram_index].values.flatten.size
      end

      # Get package count distribution by depth
      #
      # @return [Hash] Hash mapping depth to count
      def packages_by_depth
        depths = Hash.new(0)
        @indexes[:package_paths].each_key do |path|
          depth = path.split("::").size - 1
          depths[depth] += 1
        end
        depths.sort.to_h
      end

      # Get maximum package depth
      #
      # @return [Integer] Maximum depth level
      def max_depth
        return 0 if @indexes[:package_paths].empty?

        @indexes[:package_paths].keys.map do |path|
          path.split("::").size - 1
        end.max
      end

      # Get average package depth
      #
      # @return [Float] Average depth level
      def avg_package_depth
        return 0.0 if @indexes[:package_paths].empty?

        depths = @indexes[:package_paths].keys.map do |path|
          path.split("::").size - 1
        end
        depths.sum.to_f / depths.size
      end

      # Get class count grouped by stereotype
      #
      # @return [Hash] Hash mapping stereotype to count
      def classes_by_stereotype
        @indexes[:stereotypes].transform_values(&:size)
      end

      # Get most complex classes by total element count
      #
      # Complexity is measured by the sum of attributes, associations,
      # and operations.
      #
      # @param limit [Integer] Maximum number of classes to return
      # @return [Array<Hash>] Array of complexity information hashes with
      # :class and :complexity keys
      def most_complex_classes(limit: 10)
        classes = @indexes[:qualified_names].select { |_, obj| obj.is_a?(Lutaml::Uml::Class) }

        complexities = classes.map do |_qname, klass|
          {
            class: klass,
            complexity: class_complexity(klass),
          }
        end

        complexities.sort_by { |c| -c[:complexity] }.first(limit)
      end

      # Get average class complexity
      #
      # @return [Float] Average complexity score
      def avg_class_complexity
        classes = @indexes[:qualified_names].select { |_, obj| obj.is_a?(Lutaml::Uml::Class) }
        return 0.0 if classes.empty?

        total_complexity = classes.sum { |_, klass| class_complexity(klass) }
        total_complexity.to_f / classes.size
      end

      # Calculate complexity for a single class
      #
      # Complexity is the sum of attributes, associations, and operations
      #
      # @param klass [Lutaml::Uml::Class] The class to calculate complexity for
      # @return [Integer] Complexity score
      def class_complexity(klass) # rubocop:disable Metrics/CyclomaticComplexity
        (klass.attributes&.size || 0) +
          (klass.associations&.size || 0) +
          (klass.operations&.size || 0)
      end

      # Get total attribute count across all classes
      #
      # @return [Integer] Total number of attributes
      def attribute_count
        @indexes[:qualified_names].sum do |_, obj|
          next 0 unless obj.is_a?(Lutaml::Uml::Class)
          next 0 unless obj.attributes

          obj.attributes.size
        end
      end

      # Alias for attribute_count to match test expectations
      alias total_attributes attribute_count

      # Get total operation count across all classes
      #
      # @return [Integer] Total number of operations
      def total_operations
        @indexes[:qualified_names].sum do |_, obj|
          next 0 unless obj.is_a?(Lutaml::Uml::Class)
          next 0 unless obj.operations

          obj.operations.size
        end
      end

      # Get attribute type distribution
      #
      # @return [Hash] Hash mapping type names to counts
      def attribute_type_distribution # rubocop:disable Metrics/CyclomaticComplexity
        types = Hash.new(0)

        @indexes[:qualified_names].each_value do |obj|
          next unless obj.is_a?(Lutaml::Uml::Class)
          next unless obj.attributes

          obj.attributes.each do |attr|
            type_name = attr.type || "Unknown"
            types[type_name] += 1
          end
        end

        types.sort_by { |_, count| -count }.to_h
      end

      # Get total association count across all classes
      #
      # @return [Integer] Total number of associations
      def association_count
        @indexes[:qualified_names].sum do |_, obj|
          next 0 unless obj.is_a?(Lutaml::Uml::Class)
          next 0 unless obj.associations

          obj.associations.size
        end
      end

      # Get total inheritance relationship count
      #
      # @return [Integer] Number of inheritance relationships
      def inheritance_count
        @indexes[:inheritance_graph].values.flatten.size
      end

      # Get maximum inheritance depth in the model
      #
      # @return [Integer] Maximum depth of inheritance hierarchy
      def max_inheritance_depth
        return 0 if @indexes[:inheritance_graph].empty?

        @inheritance_depth_cache ||= {}
        max_depth = 0

        @indexes[:qualified_names].each_key do |qname|
          depth = memoized_inheritance_depth(qname)
          max_depth = depth if depth > max_depth
        end
        max_depth
      end

      # Calculate inheritance depth for a class
      #
      # @param qname [String] Qualified name of the class
      # @param visited [Set] Set of visited classes (to detect cycles)
      # @return [Integer] Depth of inheritance chain
      def calculate_inheritance_depth(qname, visited = Set.new)
        memoized_inheritance_depth(qname, visited)
      end

      # Build reverse index: child_qname => parent_qname
      def child_to_parent_index
        @child_to_parent_index ||= begin
          idx = {}
          @indexes[:inheritance_graph].each do |parent, children|
            children.each { |child| idx[child] = parent }
          end
          idx
        end
      end

      # Memoized inheritance depth calculation using reverse index
      def memoized_inheritance_depth(qname, visited = Set.new)
        return 0 if visited.include?(qname)
        return @inheritance_depth_cache[qname] if @inheritance_depth_cache.key?(qname)

        parent = child_to_parent_index[qname]
        return 0 unless parent

        visited.add(qname)
        depth = 1 + memoized_inheritance_depth(parent, visited)
        @inheritance_depth_cache[qname] = depth
        depth
      end

      # Get count of abstract classes
      #
      # @return [Integer] Number of abstract classes
      def abstract_class_count
        @indexes[:qualified_names].count do |_, obj|
          next false unless obj.is_a?(Lutaml::Uml::Class)

          obj.respond_to?(:is_abstract) && obj.is_abstract
        end
      end

      # Get count of classes without documentation
      #
      # @return [Integer] Number of undocumented classes
      def undocumented_classes_count
        @indexes[:qualified_names].count do |_, obj|
          next false unless obj.is_a?(Lutaml::Uml::Class)

          documentation = if obj.respond_to?(:documentation)
                            obj.documentation
                          end
          documentation.nil? || documentation.to_s.strip.empty?
        end
      end

      # Get count of classes without any attributes
      #
      # @return [Integer] Number of classes with no attributes
      def classes_without_attributes_count
        @indexes[:qualified_names].count do |_, obj|
          next false unless obj.is_a?(Lutaml::Uml::Class)

          obj.attributes.nil? || obj.attributes.empty?
        end
      end
    end
  end
end
