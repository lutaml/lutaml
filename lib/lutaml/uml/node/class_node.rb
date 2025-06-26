# frozen_string_literal: true

require "lutaml/uml/node/base"
require "lutaml/uml/node/field"
require "lutaml/uml/node/method"
require "lutaml/uml/node/relationship"
require "lutaml/uml/node/class_relationship"
require "lutaml/uml/node/has_name"

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
            when :field              then Field.new(attributes)
            when :method             then Method.new(attributes)
            when :relationship       then Relationship.new(attributes)
            when :class_relationship then ClassRelationship.new(attributes)
            end
          end
        end

        def fields
          @members.select { |member| member.instance_of?(Field) }
        end

        def methods
          @members.select { |member| member.instance_of?(Method) }
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
