# frozen_string_literal: true

module Expressir
  module Eval
    # Lexical scope chain: a name resolves to a value through the
    # innermost scope that declares it. The schema provides type
    # context; the population (step 3) provides instances for the
    # instance-aware builtins.
    class Environment
      attr_reader :schema, :population

      def initialize(schema:, population: nil, frames: [{}])
        @schema = schema
        @population = population
        @frames = frames
      end

      def push(frame)
        Environment.new(schema: @schema, population: @population,
                        frames: @frames + [frame])
      end

      def define(name, value)
        frame = @frames.last.dup
        frame[name.safe_downcase] = value
        Environment.new(schema: @schema, population: @population,
                        frames: @frames[0..-2] + [frame])
      end

      def lookup(name)
        key = name.safe_downcase
        @frames.reverse_each do |frame|
          return frame[key] if frame.key?(key)
        end
        nil
      end

      def bound?(name)
        !lookup(name).nil? || @frames.any? { |f| f.key?(name.safe_downcase) }
      end

      def interpreter
        @interpreter ||= Interpreter.new(schema: @schema,
                                         population: @population)
      end

      # Part 21 attribute slots for an entity: inherited explicit
      # attributes (supertype closure order) then the entity's own —
      # the same order the P21 validator maps values by.
      def slots_for(entity)
        @slots ||= {}
        @slots[entity] ||= begin
          inherited = entity.supertype_closure.flat_map do |supertype|
            explicit_attributes(supertype)
          end
          (inherited + explicit_attributes(entity)).each_with_index
            .to_h do |attribute, index|
            [attribute.id&.safe_downcase, index]
          end
        end
      end

      def explicit_attributes(entity)
        Array(entity.attributes)
          .select { |a| a.instance_of?(Model::Declarations::Attribute) }
      end

      def entity_for_keyword(keyword)
        Array(@schema&.entities).find do |entity|
          entity.id&.safe_downcase == keyword&.safe_downcase
        end
      end

      def instance_for(reference)
        return nil unless @population && reference.is_a?(String)
        return nil unless reference.start_with?("#")

        record = @population.instances[reference]
        record && Values::Instance.new(id: reference[1..], record: record)
      end
    end
  end
end
