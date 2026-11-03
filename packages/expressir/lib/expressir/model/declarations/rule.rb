module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.6 Rule
      class Rule < ModelElement
        include Identifier
        include ScopeContainer
        include HasInformalPropositions
        include HasWhereRules

        collection_attributes :applies_to, :types, :entities,
                              :subtype_constraints, :functions, :procedures,
                              :constants, :variables, :statements,
                              :where_rules, :informal_propositions,
                              :remark_items

        attribute :applies_to, ModelElement, collection: true, initialize_empty: true
        attribute :types, ModelElement, collection: true, initialize_empty: true
        attribute :entities, Entity, collection: true, initialize_empty: true
        attribute :subtype_constraints, SubtypeConstraint, collection: true, initialize_empty: true
        attribute :functions, Function, collection: true, initialize_empty: true
        attribute :procedures, Procedure, collection: true, initialize_empty: true
        attribute :constants, Constant, collection: true, initialize_empty: true
        attribute :variables, Variable, collection: true, initialize_empty: true
        attribute :statements, ModelElement, collection: true, initialize_empty: true
        attribute :where_rules, WhereRule, collection: true, initialize_empty: true
        attribute :informal_propositions, InformalPropositionRule,
                  collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "applies_to", to: :applies_to
          map "types", to: :types
          map "entities", to: :entities
          map "subtype_constraints", to: :subtype_constraints
          map "functions", to: :functions
          map "procedures", to: :procedures
          map "constants", to: :constants
          map "variables", to: :variables
          map "statements", to: :statements
          map "where_rules", to: :where_rules
          map "informal_propositions", to: :informal_propositions
        end

        # @return [Array<Declaration>]
        def children
          [
            *types,
            *types&.flat_map(&:enumeration_items),
            *entities,
            *subtype_constraints,
            *functions,
            *procedures,
            *constants,
            *variables,
            *where_rules,
            *informal_propositions,
            *remark_items,
          ]
        end
      end
    end
  end
end
