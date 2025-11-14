# frozen_string_literal: true

require_relative "base"
require_relative "attribute"
require_relative "operation"
require_relative "relationship"
require_relative "class_relationship"
require_relative "has_name"

module Lutaml
  module Uml
    module Node
      class ClassNode < Base
        include HasName

        attr_reader :modifier, :members

        def modifier=(value)
          @modifier = value.to_s # TODO: Validate?
        end

        def members=(value) # rubocop:disable Metrics/MethodLength
          @members = value.to_a.map do |member|
            type       = member.to_a[0][0] # TODO: This is dumb
            attributes = member.to_a[0][1]
            attributes[:parent] = self

            case type
            when :field              then Attribute.new(attributes)
            when :method             then Operation.new(attributes)
            when :relationship       then Relationship.new(attributes)
            when :class_relationship then ClassRelationship.new(attributes)
            end
          end
        end

        def attributes
          @members.select { |member| member.instance_of?(Attribute) }
        end

        def operations
          @members.select { |member| member.instance_of?(Operation) }
        end

        def relationships
          @members.select { |member| member.instance_of?(Relationship) }
        end

        def class_relationships
          @members.select { |member| member.instance_of?(ClassRelationship) }
        end
      end
    end
  end
end
