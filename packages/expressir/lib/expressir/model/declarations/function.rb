module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.5.1 Function
      class Function < ModelElement
        include Identifier
        include ScopeContainer

        collection_attributes :parameters, :types, :entities,
                              :subtype_constraints, :functions, :procedures,
                              :constants, :variables, :statements,
                              :remark_items

        attribute :parameters, Parameter, collection: true, initialize_empty: true
        attribute :return_type, ModelElement
        attribute :types, ModelElement, collection: true, initialize_empty: true
        attribute :entities, Entity, collection: true, initialize_empty: true
        attribute :subtype_constraints, SubtypeConstraint, collection: true, initialize_empty: true
        attribute :functions, Function, collection: true, initialize_empty: true
        attribute :procedures, Procedure, collection: true, initialize_empty: true
        attribute :constants, Constant, collection: true, initialize_empty: true
        attribute :variables, Variable, collection: true, initialize_empty: true
        attribute :statements, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "parameters", to: :parameters
          map "return_type", to: :return_type
          map "types", to: :types
          map "entities", to: :entities
          map "subtype_constraints", to: :subtype_constraints
          map "functions", to: :functions
          map "procedures", to: :procedures
          map "constants", to: :constants
          map "variables", to: :variables
          map "statements", to: :statements
        end

        # @return [Array<Declaration>]
        def children
          [
            *parameters,
            *types,
            *types&.flat_map(&:enumeration_items),
            *entities,
            *subtype_constraints,
            *functions,
            *procedures,
            *constants,
            *variables,
            *remark_items,
          ]
        end
      end
    end
  end
end
