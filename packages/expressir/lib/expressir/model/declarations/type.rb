module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.1 Type declaration
      class Type < ModelElement
        include Identifier
        include ScopeContainer
        include HasInformalPropositions
        include HasWhereRules

        collection_attributes :where_rules, :informal_propositions,
                              :remark_items

        attribute :underlying_type, ModelElement
        attribute :where_rules, WhereRule, collection: true, initialize_empty: true
        attribute :informal_propositions, InformalPropositionRule,
                  collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "underlying_type", to: :underlying_type
          map "where_rules", to: :where_rules
          map "informal_propositions", to: :informal_propositions
        end

        # @return [Array<DataTypes::EnumerationItem>]
        def enumeration_items
          underlying_type.is_a?(DataTypes::Enumeration) ? underlying_type.items : []
        end

        # @return [Array<Declaration>]
        def children
          [
            *enumeration_items,
            *where_rules,
            *informal_propositions,
            *remark_items,
          ]
        end
      end
    end
  end
end
