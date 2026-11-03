# frozen_string_literal: true

module Expressir
  module Express
    # Self-schema-qualified references (#125, ISO 10303-11 scope rules).
    #
    # A schema may not reference its own declarations through itself:
    # `'AIC_TOPOLOGICALLY_BOUNDED_SURFACE.B_SPLINE_SURFACE'` inside that
    # schema's TYPEOF is technically incorrect — the prefix names the
    # current schema while the item actually comes from another schema
    # (implicit through the supertype chain of a USEd entity).
    #
    # {matches} finds string literals carrying such prefixes and resolves
    # where the suffixed item truly lives (local declaration, or the
    # defining schema within the closure). {fix!} rewrites each literal in
    # place — dropping the prefix for local items, substituting the true
    # defining schema otherwise.
    module SelfSchemaReference
      Match = Struct.new(:literal, :item, :source_schema, :schema,
                         keyword_init: true) do
        # :local  - the item is declared in this schema (drop the prefix)
        # :foreign - the item's defining schema is known (substitute it)
        # :unknown - the item could not be located; left untouched
        def status
          return :local if declared_locally
          return :foreign if source_schema

          :unknown
        end

        attr_accessor :declared_locally
      end

      module_function

      # Every self-qualified string literal in +schema+.
      def matches(schema)
        prefix = /\A#{Regexp.escape(schema.id)}\.(.+)\z/i
        literals(schema).filter_map do |literal|
          suffix = literal.value[prefix, 1]
          next unless suffix

          item = suffix.strip
          declared_locally = declared?(schema, item.safe_downcase)
          source = declared_locally ? nil : defining_schema(schema, item)
          match = Match.new(literal: literal, item: item,
                            source_schema: source, schema: schema)
          match.declared_locally = declared_locally
          match
        end
      end

      # Rewrite every self-qualified literal in +schema+; returns the
      # number of rewrites. Local items lose the prefix; foreign items get
      # their true defining schema's id.
      def fix!(schema)
        matches(schema).count do |match|
          replacement = case match.status
                        when :local then match.item
                        when :foreign
                          "#{match.source_schema.id}.#{match.item}"
                        else next false
                        end

          match.literal.value = replacement
          true
        end
      end

      def literals(schema)
        result = []
        visitor = lambda do |node|
          case node
          when Model::Literals::String
            result << node
          when Model::ModelElement
            node.class.attributes.each_key do |attr|
              next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr)

              value = node.public_send(attr)
              case value
              when Array then value.each { |item| visitor.call(item) }
              when Model::ModelElement then visitor.call(value)
              end
            end
          end
        end
        visitor.call(schema)
        result
      end

      def defining_schema(schema, item)
        key = item.safe_downcase
        repository = repository_of(schema)
        return nil unless repository

        repository.schemas.each do |other|
          next if other.equal?(schema)
          next unless declared?(other, key)

          return other
        end
        nil
      end

      def declared?(schema, key)
        %i[types entities functions procedures constants rules
           subtype_constraints].any? do |coll|
          Array(schema.public_send(coll)).any? do |decl|
            decl.respond_to?(:id) && decl.id&.safe_downcase == key
          end
        end
      end

      def repository_of(schema)
        current = schema.parent
        while current
          return current if current.is_a?(Model::Repository)

          current = current.respond_to?(:parent) ? current.parent : nil
        end
        nil
      end
    end
  end
end
