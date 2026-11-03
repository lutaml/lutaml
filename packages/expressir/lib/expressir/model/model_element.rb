require "pathname"

module Expressir
  module Model
    # Base model element
    class ModelElement < Lutaml::Model::Serializable
      # ---- Collection-attributes macro (TODO.bugs/12) ----
      #
      # Each model class declares which attributes hold child collections
      # via `collection_attributes :foo, :bar, ...`. The declarations
      # auto-register into the global registry, eliminating the need for
      # a hand-maintained hash in NodePositionIndex.

      # Returns the global registry: class → array of attr symbols.
      def self.collection_registry
        @collection_registry ||= {}
      end

      # Returns the collection attributes declared on this class (empty
      # if none declared).
      def self.collection_attributes_list
        @collection_attributes || []
      end

      # Declare which attributes on this model class hold child collections
      # that should be traversed by tree-walkers (NodePositionIndex,
      # RemarkAttacher, ScopeResolver). Also registers this class in the
      # global collection registry so NodePositionIndex can derive its
      # COLLECTION_REGISTRY from the model instead of duplicating it.
      def self.collection_attributes(*attrs)
        @collection_attributes = attrs.freeze
        ModelElement.collection_registry[self] = attrs
      end

      # ---- End collection-attributes macro ----

      # ---- Child-attributes macro (TODO.bugs/15) ----
      #
      # Similar to collection_attributes, but for single-value ModelElement
      # children (non-collection attributes that hold a ModelElement, like
      # BinaryExpression#operand1). Used by RemarkAttacher for query
      # traversal so the EXPRESSION_CHILDREN hash lives on the model.

      # Returns the global registry: class → array of attr symbols.
      def self.child_attributes_registry
        @child_attributes_registry ||= {}
      end

      # Returns the child attributes declared on this class (empty if none).
      def self.child_attributes_list
        @child_attributes || []
      end

      # Declare which attributes on this model class hold single-value
      # ModelElement children that should be traversed by the remark
      # attacher's query-search.
      def self.child_attributes(*attrs)
        @child_attributes = attrs.freeze
        ModelElement.child_attributes_registry[self] = attrs
      end

      # ---- End child-attributes macro ----

      # :source is skipped deliberately: its reader formats the node,
      # and reading it during construction (attach_parent_to_children on
      # a from_hash-built object whose attributes are not yet applied)
      # would memoize an incomplete rendering forever.
      SKIP_ATTRIBUTES = %i[parent _class source].freeze
      # :parent is a special attribute that is used to store the parent of the current element
      # It is not a real attribute
      # attribute :parent, ModelElement
      attr_accessor :parent

      attribute :_class, :string, default: -> { self.class.name },
                                  polymorphic_class: true
      attribute :source, :string
      attribute :source_offset, :integer
      attribute :untagged_remarks, RemarkInfo, collection: true, initialize_empty: true

      POLYMORPHIC_CLASS_MAP = {
        "Expressir::Model::Cache" => "Expressir::Model::Cache",
        "Expressir::Model::ExpFile" => "Expressir::Model::ExpFile",
        "Expressir::Model::Repository" => "Expressir::Model::Repository",
        "Expressir::Model::RemarkInfo" => "Expressir::Model::RemarkInfo",
        "Expressir::Model::DataTypes::Aggregate" => "Expressir::Model::DataTypes::Aggregate",
        "Expressir::Model::DataTypes::Array" => "Expressir::Model::DataTypes::Array",
        "Expressir::Model::DataTypes::Bag" => "Expressir::Model::DataTypes::Bag",
        "Expressir::Model::DataTypes::Binary" => "Expressir::Model::DataTypes::Binary",
        "Expressir::Model::DataTypes::Boolean" => "Expressir::Model::DataTypes::Boolean",
        "Expressir::Model::DataTypes::EnumerationItem" => "Expressir::Model::DataTypes::EnumerationItem",
        "Expressir::Model::DataTypes::Enumeration" => "Expressir::Model::DataTypes::Enumeration",
        "Expressir::Model::DataTypes::GenericEntity" => "Expressir::Model::DataTypes::GenericEntity",
        "Expressir::Model::DataTypes::Generic" => "Expressir::Model::DataTypes::Generic",
        "Expressir::Model::DataTypes::Integer" => "Expressir::Model::DataTypes::Integer",
        "Expressir::Model::DataTypes::List" => "Expressir::Model::DataTypes::List",
        "Expressir::Model::DataTypes::Logical" => "Expressir::Model::DataTypes::Logical",
        "Expressir::Model::DataTypes::Number" => "Expressir::Model::DataTypes::Number",
        "Expressir::Model::DataTypes::Real" => "Expressir::Model::DataTypes::Real",
        "Expressir::Model::DataTypes::Select" => "Expressir::Model::DataTypes::Select",
        "Expressir::Model::DataTypes::Set" => "Expressir::Model::DataTypes::Set",
        "Expressir::Model::DataTypes::String" => "Expressir::Model::DataTypes::String",
        "Expressir::Model::Declarations::DerivedAttribute" => "Expressir::Model::Declarations::DerivedAttribute",
        "Expressir::Model::Declarations::Attribute" => "Expressir::Model::Declarations::Attribute",
        "Expressir::Model::Declarations::Constant" => "Expressir::Model::Declarations::Constant",
        "Expressir::Model::Declarations::Entity" => "Expressir::Model::Declarations::Entity",
        "Expressir::Model::Declarations::Function" => "Expressir::Model::Declarations::Function",
        "Expressir::Model::Declarations::InterfaceItem" => "Expressir::Model::Declarations::InterfaceItem",
        "Expressir::Model::Declarations::InverseAttribute" => "Expressir::Model::Declarations::InverseAttribute",
        "Expressir::Model::Declarations::Interface" => "Expressir::Model::Declarations::Interface",
        "Expressir::Model::Declarations::InterfacedItem" => "Expressir::Model::Declarations::InterfacedItem",
        "Expressir::Model::Declarations::Parameter" => "Expressir::Model::Declarations::Parameter",
        "Expressir::Model::Declarations::Procedure" => "Expressir::Model::Declarations::Procedure",
        "Expressir::Model::Declarations::RemarkItem" => "Expressir::Model::Declarations::RemarkItem",
        "Expressir::Model::Declarations::InformalPropositionRule" => "Expressir::Model::Declarations::InformalPropositionRule",
        "Expressir::Model::Declarations::Rule" => "Expressir::Model::Declarations::Rule",
        "Expressir::Model::Declarations::SchemaVersionItem" => "Expressir::Model::Declarations::SchemaVersionItem",
        "Expressir::Model::Declarations::SchemaVersion" => "Expressir::Model::Declarations::SchemaVersion",
        "Expressir::Model::Declarations::Schema" => "Expressir::Model::Declarations::Schema",
        "Expressir::Model::Declarations::SubtypeConstraint" => "Expressir::Model::Declarations::SubtypeConstraint",
        "Expressir::Model::Declarations::Type" => "Expressir::Model::Declarations::Type",
        "Expressir::Model::Declarations::UniqueRule" => "Expressir::Model::Declarations::UniqueRule",
        "Expressir::Model::Declarations::Variable" => "Expressir::Model::Declarations::Variable",
        "Expressir::Model::Declarations::WhereRule" => "Expressir::Model::Declarations::WhereRule",
        "Expressir::Model::Expressions::AggregateInitializerItem" => "Expressir::Model::Expressions::AggregateInitializerItem",
        "Expressir::Model::Expressions::AggregateInitializer" => "Expressir::Model::Expressions::AggregateInitializer",
        "Expressir::Model::Expressions::BinaryExpression" => "Expressir::Model::Expressions::BinaryExpression",
        "Expressir::Model::Expressions::EntityConstructor" => "Expressir::Model::Expressions::EntityConstructor",
        "Expressir::Model::Expressions::FunctionCall" => "Expressir::Model::Expressions::FunctionCall",
        "Expressir::Model::Expressions::Interval" => "Expressir::Model::Expressions::Interval",
        "Expressir::Model::Expressions::QueryExpression" => "Expressir::Model::Expressions::QueryExpression",
        "Expressir::Model::Expressions::UnaryExpression" => "Expressir::Model::Expressions::UnaryExpression",
        "Expressir::Model::Literals::Binary" => "Expressir::Model::Literals::Binary",
        "Expressir::Model::Literals::Integer" => "Expressir::Model::Literals::Integer",
        "Expressir::Model::Literals::Logical" => "Expressir::Model::Literals::Logical",
        "Expressir::Model::Literals::Real" => "Expressir::Model::Literals::Real",
        "Expressir::Model::Literals::String" => "Expressir::Model::Literals::String",
        "Expressir::Model::References::AttributeReference" => "Expressir::Model::References::AttributeReference",
        "Expressir::Model::References::GroupReference" => "Expressir::Model::References::GroupReference",
        "Expressir::Model::References::IndexReference" => "Expressir::Model::References::IndexReference",
        "Expressir::Model::References::SimpleReference" => "Expressir::Model::References::SimpleReference",
        "Expressir::Model::Statements::Alias" => "Expressir::Model::Statements::Alias",
        "Expressir::Model::Statements::Assignment" => "Expressir::Model::Statements::Assignment",
        "Expressir::Model::Statements::CaseAction" => "Expressir::Model::Statements::CaseAction",
        "Expressir::Model::Statements::Case" => "Expressir::Model::Statements::Case",
        "Expressir::Model::Statements::Compound" => "Expressir::Model::Statements::Compound",
        "Expressir::Model::Statements::Escape" => "Expressir::Model::Statements::Escape",
        "Expressir::Model::Statements::If" => "Expressir::Model::Statements::If",
        "Expressir::Model::Statements::Null" => "Expressir::Model::Statements::Null",
        "Expressir::Model::Statements::ProcedureCall" => "Expressir::Model::Statements::ProcedureCall",
        "Expressir::Model::Statements::Repeat" => "Expressir::Model::Statements::Repeat",
        "Expressir::Model::Statements::Return" => "Expressir::Model::Statements::Return",
        "Expressir::Model::Statements::Skip" => "Expressir::Model::Statements::Skip",
        "Expressir::Model::SupertypeExpressions::BinarySupertypeExpression" => "Expressir::Model::SupertypeExpressions::BinarySupertypeExpression",
        "Expressir::Model::SupertypeExpressions::OneofSupertypeExpression" => "Expressir::Model::SupertypeExpressions::OneofSupertypeExpression",
      }.freeze

      key_value do
        map "_class", to: :_class, render_default: true,
                      polymorphic_map: POLYMORPHIC_CLASS_MAP
        # Hydrate-only: byte positions ride the wire (Rust core path)
        # without ever appearing in to_hash — the serialized shape stays
        # identical to the Ruby-built model.
        map "source_offset", to: :source_offset, serialize: false
      end

      def source
        # Formatting is not free and callers probe `source` repeatedly while
        # walking the tree (position index, remark attachment), so the text is
        # computed once per node. Deliberately NOT @source: that ivar holds
        # the raw source span lutaml-model's `source=` stores when
        # include_source is on, and readers must keep seeing formatted text.
        @formatted_source ||= Expressir::Express::SourceFormatter.format(self) # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      # @param [Hash] options
      def initialize(_options = {})
        super
        attach_parent_to_children
      end

      # @return [String]
      def path
        # this creates an implicit scope
        return if is_a?(Statements::Alias) || is_a?(Statements::Repeat) || is_a?(Expressions::QueryExpression)

        current_node = self
        path_parts = []
        loop do
          # Skip adding the id if this is a RemarkItem that belongs to an InformalPropositionRule
          # and has the same id as its parent
          if !(current_node.is_a? References::SimpleReference) && current_node.is_a?(HasId) &&
              !(is_a?(Declarations::RemarkItem) &&
                parent.is_a?(Declarations::InformalPropositionRule) &&
                id == parent.id)
            path_parts << current_node.id
          end

          current_node = current_node.parent
          break unless current_node
        end

        return if path_parts.empty?

        path_parts.reverse.join(".")
      end

      # @param [String] path
      # @return [ModelElement]
      def find(path)
        return self if path.nil? || path.empty?

        path_parts = path.safe_downcase.split(".").map do |current_path|
          # `__note:two` is a remark item id, not a prefixed name
          next current_path if current_path.start_with?("__")

          _, _, current_path = current_path.rpartition(":") # ignore prefix
          current_path
        end

        current_scope = self
        target_node = nil
        loop do
          target_node = resolve_path_in_scope(current_scope, path_parts)
          break if target_node

          current_scope = current_scope.parent
          break unless current_scope
        end

        if target_node.is_a? Model::Declarations::InterfacedItem
          target_node = target_node.base_item
        end

        target_node
      end

      # Walk `path_parts` through `scope`, resolving one part at a time.
      # Handles `SELF\<supertype>.<attr>` qualifiers inline: when a part
      # starts with `self\`, the next part is matched against the scope's
      # redeclared attributes and disambiguated by the supertype name
      # (issues #130 and #267).
      def resolve_path_in_scope(scope, path_parts)
        current_node = scope
        pending_supertype = nil

        path_parts.each do |current_path|
          if current_path.start_with?("self\\")
            pending_supertype = current_path.split("\\", 2).last
            next
          end

          if pending_supertype
            child = find_redeclared_by_supertype(current_node, current_path,
                                                 pending_supertype)
            return nil unless child

            current_node = child
            pending_supertype = nil
          else
            current_node = current_node.children_by_id[current_path]
            return nil unless current_node
          end
        end

        # If the path ended on a SELF qualifier (no attr name followed),
        # resolution is incomplete.
        pending_supertype ? nil : current_node
      end

      # Find a redeclared attribute among `scope`'s children whose id matches
      # `attr_name` and whose supertype_attribute references the given
      # `supertype` name. Returns nil if `scope` is not an Attribute container
      # or no such child exists.
      def find_redeclared_by_supertype(scope, attr_name, supertype)
        attrs = scope.respond_to?(:attributes) ? scope.attributes : nil
        return nil unless attrs

        attrs.find do |child|
          next false unless child.is_a?(Model::Declarations::Attribute)
          next false unless child.id&.safe_downcase == attr_name

          supertype_attr = child.supertype_attribute
          next false unless supertype_attr.respond_to?(:ref)

          group_ref = supertype_attr.ref
          next false unless group_ref.respond_to?(:entity)

          entity_ref = group_ref.entity
          entity_ref&.id&.safe_downcase == supertype
        end
      end

      # Wire the parent pointers of this node's entire subtree. Needed
      # for models materialized outside the builders (e.g. hydrated
      # from the Rust core path), whose parents start unset.
      def wire_parents(parent = nil)
        self.parent = parent
        self.class.attributes.each_key do |attr|
          next if SKIP_ATTRIBUTES.include?(attr) || attr == :parent

          value = public_send(attr)
          case value
          when Array
            value.each { |v| v.wire_parents(self) if v.is_a?(ModelElement) }
          when ModelElement
            value.wire_parents(self)
          end
        end
      end

      # @return [Array<Declaration>]
      def children
        []
      end

      # @return [Hash<String, Declaration>]
      def children_by_id
        @children_by_id ||= children.select(&:id).to_h do |x|
          [x.id.safe_downcase, x]
        end
      end

      # @return [nil]
      def reset_children_by_id
        @children_by_id = nil
        nil
      end

      # Format this element back into EXPRESS source text.
      # @param no_remarks [Boolean] omit remarks from the output
      # @param formatter [Express::Formatter, nil] use a specific formatter
      # @return [String]
      def format(no_remarks: false, formatter: nil)
        f = formatter || Express::Formatter.new(no_remarks: no_remarks)
        f.format(self)
      end

      # No-arg delegator so string interpolation ("#{element}") still
      # produces EXPRESS source rather than the default Object#to_s.
      # Remark-free output is requested explicitly through
      # #format(no_remarks: true); it is not this method's default.
      def to_s
        format
      end

      # Add a remark to this element
      # @param remark_info [RemarkInfo] Remark to add
      def add_remark(remark_info)
        self.untagged_remarks ||= []
        return unless remark_info.is_a?(RemarkInfo)

        untagged_remarks << remark_info
      end

      private

      # @return [nil]
      def attach_parent_to_children
        self.class.attributes.each_pair do |symbol, _lutaml_attr|
          next if SKIP_ATTRIBUTES.include?(symbol)

          value = public_send(symbol)

          case value
          when Array
            value.each do |val|
              if val.is_a?(ModelElement)
                val.parent = self
              end
            end
          when ModelElement
            value.parent = self
          end
        end

        nil
      end
    end
  end
end
