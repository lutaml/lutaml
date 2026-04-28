# frozen_string_literal: true

module Lutaml
  module Uml
    # Service class for safely walking UML generalization chains.
    #
    # Walks from a class up through its generalization hierarchy (parent classes),
    # collecting information about each ancestor. Supports cycle detection to
    # prevent infinite loops in malformed models.
    #
    # @example
    #   walker = InheritanceWalker.new(repository)
    #   walker.walk(klass) do |ancestor, level|
    #     puts "#{'-' * level} #{ancestor.name}"
    #   end
    class InheritanceWalker
      # @param repository [#supertype_of] Object responding to #supertype_of(class)
      def initialize(repository)
        @repository = repository
        @visited = Set.new
      end

      # Walk the generalization chain from a starting class.
      #
      # @param klass [Lutaml::Uml::Class] The class to start from
      # @yield [ancestor, level] Yields each ancestor class and its depth (1-based)
      # @return [Array<[klass, level]>] Array of [ancestor_class, level] pairs in visiting order
      #
      # @example
      #   walker.walk(D.class) do |parent, level|
      #     puts "#{'  ' * (level - 1)}Parent #{level}: #{parent.name}"
      #   end
      def walk(klass)
        return [] unless klass.respond_to?(:generalization) && klass.generalization

        ancestors = []
        @visited.clear
        collect_ancestors(klass, ancestors)
        ancestors.reverse_each.with_index(1) do |ancestor, level|
          break if @visited.include?(ancestor.xmi_id)
          @visited.add(ancestor.xmi_id)
          yield(ancestor, level) if block_given?
        end
        ancestors.reverse_each.with_index(1)
      end

      # Get the direct supertype (immediate parent) of a class.
      #
      # @param klass [Lutaml::Uml::Class]
      # @return [Lutaml::Uml::Class, nil]
      def supertype_of(klass)
        @repository.supertype_of(klass)
      end

      # Get all ancestors of a class in order (immediate parent first).
      #
      # @param klass [Lutaml::Uml::Class]
      # @return [Array<Lutaml::Uml::Class>]
      def ancestors_of(klass)
        result = []
        walk(klass) { |ancestor, _level| result << ancestor }
        result
      end

      private

      # Collect ancestors recursively into the result array.
      # Uses a trail set for cycle detection (avoids Set mutation issues across calls).
      def collect_ancestors(klass, result, trail = [])
        return [] if trail.include?(klass.xmi_id) # cycle guard
        return [] unless klass.respond_to?(:generalization) && klass.generalization

        trail = trail.dup
        trail << klass.xmi_id

        general_id = klass.generalization.respond_to?(:general_id) ? klass.generalization.general_id : nil
        parent = general_id ? find_class_by_id(general_id) : nil

        return [] unless parent

        result << parent
        collect_ancestors(parent, result, trail)
      end

      def find_class_by_id(xmi_id)
        @repository.indexes&.dig(:qualified_names, xmi_id) ||
          @repository.send(:classes_index)&.find { |c| c.xmi_id == xmi_id }
      end
    end
  end
end
