# frozen_string_literal: true

require "lutaml/uml/formatter"
require "lutaml/uml/has_attributes"

module Lutaml
  module Uml
    module Formatter
      class Base
        class << self
          def inherited(subclass)
            Formatter.all << subclass
          end

          def format(node, attributes = {})
            new(attributes).format(node)
          end

          def name
            to_s.split("::").last.downcase.to_sym
          end
        end

        include HasAttributes

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

        def format(node)
          case node
          when Node::Field  then format_field(node)
          when Node::Method then format_method(node)
          when Node::Relationship then format_relationship(node)
          when Node::ClassRelationship then format_class_relationship(node)
          when Node::ClassNode then format_class(node)
          when Lutaml::Uml::Document then format_document(node)
          end
        end

        def format_field(_node);              raise NotImplementedError; end

        def format_method(_node);             raise NotImplementedError; end

        def format_relationship(_node);       raise NotImplementedError; end

        def format_class_relationship(_node); raise NotImplementedError; end

        def format_class(_node);              raise NotImplementedError; end

        def format_document(_node);           raise NotImplementedError; end
      end
    end
  end
end
