module Expressir
  module Model
    module Statements
      # Specified in ISO 10303-11:2004
      # - section 13.4 Case statement
      class Case < ModelElement
        include Statement

        # The executable bodies of a CASE, exposed as ordered statement
        # lists. Tree-walkers traverse these rather than `actions`, because
        # a CaseAction is a label wrapper the parser gives no usable source
        # position — the statement inside it carries the position that
        # matters for placing comments.
        collection_attributes :action_statements, :otherwise_statements

        child_attributes :expression
        attribute :expression, ModelElement
        attribute :actions, CaseAction, collection: true, initialize_empty: true
        attribute :otherwise_statement, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        # @return [Array<ModelElement>] each action's statement, in order
        def action_statements
          Array(actions).filter_map(&:statement)
        end

        # @return [Array<ModelElement>] the OTHERWISE body, if present
        def otherwise_statements
          [otherwise_statement].compact
        end

        key_value do
          map "_class", to: :_class, render_default: true
          map "untagged_remarks", to: :untagged_remarks
          map "expression", to: :expression
          map "actions", to: :actions
          map "otherwise_statement", to: :otherwise_statement
        end
      end
    end
  end
end
