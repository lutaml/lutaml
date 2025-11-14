# frozen_string_literal: true

require_relative "../formatter"
require_relative "../uml/has_attributes"

module Lutaml
  module Formatter
    class Base
      class << self
        def inherited(subclass) # rubocop:disable Lint/MissingSuper
          Formatter.all << subclass
        end

        def format(node, attributes = {})
          new(attributes).format(node)
        end

        def name
          to_s.split("::").last.downcase.to_sym
        end
      end

      include ::Lutaml::Uml::HasAttributes

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases

      def name
        self.class.name
      end

      attr_reader :type

      def type=(value)
        @type = value.to_s.strip.downcase.to_sym
      end

      def format(node) # rubocop:disable Metrics/CyclomaticComplexity
        case node
        when ::Lutaml::Uml::Node::Attribute then format_attribute(node)
        when ::Lutaml::Uml::Node::Operation then format_operation(node)
        when ::Lutaml::Uml::Node::Relationship then format_relationship(node)
        when ::Lutaml::Uml::Node::ClassRelationship
          format_class_relationship(node)
        when ::Lutaml::Uml::Node::ClassNode then format_class(node)
        when ::Lutaml::Uml::Document then format_document(node)
        end
      end

      def format_attribute(_node); raise NotImplementedError; end

      def format_operation(_node); raise NotImplementedError; end

      def format_relationship(_node);       raise NotImplementedError; end

      def format_class_relationship(_node); raise NotImplementedError; end

      def format_class(_node);              raise NotImplementedError; end

      def format_document(_node);           raise NotImplementedError; end
    end
  end
end
