module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.3 Schema
      class Schema < ModelElement
        include Identifier
        include ScopeContainer

        # Tree-walker collection attributes (TODO.bugs/12 — single source
        # of truth; NodePositionIndex derives COLLECTION_REGISTRY from this).
        collection_attributes :interfaces, :constants, :types, :entities,
                              :subtype_constraints, :functions, :rules,
                              :procedures, :remark_items

        # Subset of this schema's collection attributes that hold named
        # scope declarations (Function, Procedure, Rule, Entity, Type).
        # Used by ScopeResolver to enumerate scope-capable children without
        # duplicating the list. Single source of truth: this is the subset
        # of NodePositionIndex::COLLECTION_REGISTRY[Schema] that holds
        # scopes rather than remark_items / constants / subtype_constraints.
        SCOPE_DECL_COLLECTIONS = %i[
          functions procedures rules entities types
        ].freeze

        attribute :file, :string
        attribute :version, SchemaVersion
        attribute :interfaces, Interface, collection: true, initialize_empty: true
        attribute :constants, Constant, collection: true, initialize_empty: true
        attribute :types, ModelElement, collection: true, initialize_empty: true
        attribute :entities, Entity, collection: true, initialize_empty: true
        attribute :subtype_constraints, SubtypeConstraint, collection: true, initialize_empty: true
        attribute :functions, Function, collection: true, initialize_empty: true
        attribute :rules, Rule, collection: true, initialize_empty: true
        attribute :procedures, Procedure, collection: true, initialize_empty: true
        attribute :header, :string
        attribute :_class, :string, default: -> { self.class.name }
        attribute :selected, :boolean, default: false
        attribute :file_basename, :string

        key_value do
          map "_class", to: :_class, render_default: true
          map "id", to: :id
          map "file", to: :file
          map "header", to: :header
          map "remarks", to: :remarks
          map "remark_items", to: :remark_items
          map "version", to: :version
          map "interfaces", to: :interfaces
          map "constants", to: :constants
          map "types", to: :types
          map "entities", to: :entities
          map "subtype_constraints", to: :subtype_constraints
          map "functions", to: :functions
          map "rules", to: :rules
          map "procedures", to: :procedures
        end

        liquid do
          map :header, to: :header
          map :formatted, to: :formatted
          map :formatted_hyperlinked, to: :formatted_hyperlinked
          map :formatted_hyperlinked_adoc, to: :formatted_hyperlinked_adoc
          map :source, to: :source
          map :source_hyperlinked, to: :source_hyperlinked
          map :full_source, to: :full_source
          map :children, to: :children
          map :safe_children, to: :safe_children
        end

        # @return [Array<Declaration>]
        def safe_children
          [
            *constants,
            *types,
            *types&.flat_map(&:enumeration_items),
            *entities,
            *subtype_constraints,
            *functions,
            *rules,
            *procedures,
            *remark_items,
          ]
        end

        # @return [Array<Declaration>]
        def children
          [
            *interfaced_items,
            *safe_children,
          ]
        end

        def full_source
          @full_source ||= Expressir::Express::Formatter.format(self)
        end

        def formatted
          @formatted ||= format(no_remarks: false)
        end

        # Schema head text without hyperlinks (#255) — the `source` face
        # templates call for the verbatim schema declaration block.
        # Deliberately NOT @source: that ivar holds the raw source span
        # lutaml-model's `source=` stores when include_source is on.
        def source
          @plain_source ||= Expressir::Express::SchemaPlainSourceFormatter.format(self) # rubocop:disable Naming/MemoizedInstanceVariableName
        end

        # Schema head text with cross-references rendered as hyperlinks
        # (#255) — the hyperlinked counterpart of #source.
        def source_hyperlinked
          Expressir::Express::SchemaSourceFormatter.format(self)
        end

        # FULL schema text with cross-references rendered as hyperlinks
        # — what a schema document page renders (#255): every line of
        # the schema, live links included.
        def formatted_hyperlinked
          @formatted_hyperlinked ||= Expressir::Express::SourceFormatter.format(self)
        end

        # FULL schema text with cross-references as AsciiDoc xref macros
        # (+<<schema.item,item>>+) — drop-in for a schema document page
        # rendered through a +subs="+macros"+ source block.
        def formatted_hyperlinked_adoc
          @formatted_hyperlinked_adoc ||= Expressir::Express::AdocSourceFormatter.format(self)
        end

        USE_ITEM_KINDS = [
          Expressir::Model::Declarations::Entity,
          Expressir::Model::Declarations::Type,
        ].freeze

        REFERENCE_ITEM_KINDS = [
          Expressir::Model::Declarations::Constant,
          Expressir::Model::Declarations::Entity,
          Expressir::Model::Declarations::Function,
          Expressir::Model::Declarations::Procedure,
          Expressir::Model::Declarations::Type,
        ].freeze

        private

        # @param [String] id
        # @param [ModelElement] base_item
        # @return [InterfacedItem]
        def create_interfaced_item(id, base_item)
          interfaced_item = InterfacedItem.new(
            id: id,
          )
          interfaced_item.base_item = base_item # skip overriding parent
          interfaced_item.parent = self
          interfaced_item
        end

        # @return [Array<InterfacedItem>]

        def interfaced_items
          return [] unless parent

          visited_schemas = {}
          interfaces.flat_map do |interface|
            items_for_interface(interface, visited_schemas)
          end.compact
        end

        # ISO 10303-11 implicit interfacing: USE exposes entities and
        # types only; REFERENCE has no implicit interfacing. Listed
        # items follow eeng resolve-interface: use-from resolves via
        # find-type/entity, reference-from via the 5-kind or-chain.

        # Direct items of one interface plus the items visible through
        # the foreign schema's own USE interfaces (transitive USE
        # visibility, eeng :use-only → :use-from recursion).
        def items_for_interface(interface, visited_schemas)
          schema = foreign_schema(interface.schema.id.safe_downcase)
          return [] unless schema
          # Visited means this schema's contribution is already in the
          # caller's result: re-entering — mutual USE FROM included —
          # recursed forever when the interface carried an item list
          # (the old guard only fired for the list-less form).
          return [] if visited_schemas.key?(schema.id.safe_downcase)

          visited_schemas[schema.id.safe_downcase] = true

          safe_children = schema.safe_children
          children_by_id = safe_children.each_with_object({}) do |child, hash|
            hash[child.id.safe_downcase] = child if child.id
          end

          own = if interface.items.empty?
                  if interface.kind == Interface::REFERENCE
                    []
                  else
                    safe_children.filter_map do |base_item|
                      next nil unless USE_ITEM_KINDS.any? { |k| base_item.is_a?(k) }

                      create_interfaced_item(base_item.id, base_item)
                    end
                  end
                else
                  interface.items.filter_map do |item|
                    base_item = children_by_id[item.ref.id.safe_downcase]
                    next nil unless base_item
                    next nil unless item_kind_interfacable?(interface.kind, base_item)

                    create_interfaced_item(item.id || base_item.id,
                                           base_item)
                  end
                end

          # Transitive items are not restricted by this interface's
          # item list: implicit interfacing through USE is unfiltered
          # (eeng :use-only → :use-from recursion finds any id in the
          # foreign schema's use scope).
          own + Array(schema.interfaces).filter_map do |foreign_iface|
            next nil unless foreign_iface.kind == Interface::USE

            foreign_items = items_for_interface(foreign_iface,
                                                visited_schemas)
            foreign_items.empty? ? nil : foreign_items
          end.flatten
        end

        def item_kind_interfacable?(kind, node)
          kinds = kind == Interface::REFERENCE ? REFERENCE_ITEM_KINDS : USE_ITEM_KINDS
          kinds.any? { |k| node.is_a?(k) }
        end

        # Find a foreign schema by name: same file first, then the
        # enclosing repository (expressir's compiled/batch repository).
        def foreign_schema(name)
          current = parent
          while current
            return current.children_by_id[name] if current.respond_to?(:children_by_id) &&
              current.children_by_id[name]

            current = current.is_a?(ModelElement) ? current.parent : nil
          end
          nil
        end
      end
    end
  end
end
