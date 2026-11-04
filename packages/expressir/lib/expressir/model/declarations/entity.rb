module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.2 Entity declaration
      class Entity < ModelElement
        include Identifier
        include ScopeContainer
        include HasInformalPropositions
        include HasWhereRules

        collection_attributes :attributes, :derived_attributes,
                              :inverse_attributes, :unique_rules,
                              :where_rules, :informal_propositions,
                              :remark_items

        attribute :abstract, :boolean
        attribute :supertype_expression, ModelElement
        attribute :subtype_of, ModelElement, collection: true, initialize_empty: true
        # Heterogeneous by design: Attribute, DerivedAttribute, and
        # InverseAttribute all live here (the builders concatenate the
        # three clauses in declaration order). The ModelElement base
        # keeps from_hash polymorphic via the _class marker, exactly
        # like the Ruby-built model.
        attribute :attributes, ModelElement, collection: true, initialize_empty: true
        attribute :derived_attributes, DerivedAttribute, collection: true, initialize_empty: true
        attribute :inverse_attributes, InverseAttribute, collection: true, initialize_empty: true
        attribute :unique_rules, UniqueRule, collection: true, initialize_empty: true
        attribute :where_rules, WhereRule, collection: true, initialize_empty: true
        attribute :informal_propositions, InformalPropositionRule,
                  collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "abstract", to: :abstract
          map "supertype_expression", to: :supertype_expression
          map "subtype_of", to: :subtype_of
          map "attributes", to: :attributes
          map "derived_attributes", to: :derived_attributes
          map "inverse_attributes", to: :inverse_attributes
          map "unique_rules", to: :unique_rules
          map "where_rules", to: :where_rules
          map "informal_propositions", to: :informal_propositions
        end

        # @return [Array<Declaration>]
        def children
          [
            *attributes,
            *derived_attributes,
            *inverse_attributes,
            *unique_rules,
            *where_rules,
            *informal_propositions,
            *remark_items,
          ]
        end

        # eeng compute-inheritance: the full supertype closure, nearest
        # supertype first, cycle-safe. Cross-schema supertypes resolve
        # through the enclosing repository.
        # @return [Array<Entity>]
        def supertype_closure
          closure = []
          visited = { id&.safe_downcase => true }
          queue = Array(subtype_of).map { |ref| ref.respond_to?(:id) ? ref.id : ref }
          while (name = queue.shift)
            key = name&.safe_downcase
            next if key.nil? || visited.key?(key)

            supertype = find_supertype_entity(key)
            next unless supertype

            visited[key] = true
            closure << supertype
            queue.concat(Array(supertype.subtype_of).map do |ref|
              ref.respond_to?(:id) ? ref.id : ref
            end)
          end
          closure
        end

        # Explicit attributes inherited from the supertype closure,
        # nearest supertype first, skipping ids this entity (or a
        # nearer ancestor) redeclares.
        # @return [Array<ExplicitAttribute>]
        def inherited_explicit_attributes
          claimed = explicit_only(Array(attributes)).filter_map(&:id).map(&:safe_downcase)
          closure = supertype_closure
          closure.flat_map do |supertype|
            explicit_only(Array(supertype.attributes)).filter_map do |attr|
              next nil unless attr.id

              key = attr.id.safe_downcase
              next nil if claimed.include?(key)

              claimed << key
              attr
            end
          end
        end

        # Derived attributes accumulated from the supertype closure.
        # @return [Array<DerivedAttribute>]
        def inherited_derived_attributes
          closure = supertype_closure
          seen = {}
          closure.flat_map do |supertype|
            derived_attribute_items(supertype).filter_map do |attr|
              next nil unless attr.id

              key = attr.id.safe_downcase
              next nil if seen.key?(key)

              seen[key] = true
              attr
            end
          end
        end

        # Inverse attributes accumulated from the supertype closure.
        # @return [Array<InverseAttribute>]
        def inherited_inverse_attributes
          closure = supertype_closure
          seen = {}
          closure.flat_map do |supertype|
            inverse_attribute_items(supertype).filter_map do |attr|
              next nil unless attr.id

              key = attr.id.safe_downcase
              next nil if seen.key?(key)

              seen[key] = true
              attr
            end
          end
        end

        # All explicit attributes: own + inherited (eeng
        # explicit-attrs materialization).
        # @return [Array<ExplicitAttribute>]
        def all_explicit_attributes
          [*explicit_only(Array(attributes)), *inherited_explicit_attributes]
        end

        private

        # Entity#attributes carries every attribute kind; the explicit
        # kind is Expressir::Model::Declarations::Attribute.
        # DerivedAttribute/InverseAttribute subclass Attribute, so the
        # explicit kind is the exact base class.
        def explicit_only(attrs)
          attrs.select { |a| a.instance_of?(Expressir::Model::Declarations::Attribute) }
        end

        # The Ruby parse path parks every attribute kind in `attributes`
        # (typed by class); the core path fills derived_attributes/
        # inverse_attributes instead. Both layouts resolve to the same
        # items here.
        def derived_attribute_items(entity)
          own = Array(entity.derived_attributes)
          return own if own.any?

          Array(entity.attributes).grep(Expressir::Model::Declarations::DerivedAttribute)
        end

        def inverse_attribute_items(entity)
          own = Array(entity.inverse_attributes)
          return own if own.any?

          Array(entity.attributes).grep(Expressir::Model::Declarations::InverseAttribute)
        end

        def find_supertype_entity(key)
          container = parent
          container = container.parent while container &&
              !container.is_a?(Model::Repository) &&
              !container.is_a?(Model::ExpFile)
          return nil unless container.respond_to?(:schemas)

          container.schemas.each do |foreign|
            next unless foreign.respond_to?(:entities)

            foreign.entities.each do |candidate|
              return candidate if candidate.id&.safe_downcase == key
            end
          end
          nil
        end
      end
    end
  end
end
