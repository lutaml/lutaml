# frozen_string_literal: true

module Expressir
  module Express
    # EXPRESS → XML Schema writer (expressir #276 step 2,
    # TODO.parity-ee 15) — the express2xsd counterpart, built on
    # moxml.
    #
    # Mapping (v2):
    #   ENTITY      → xs:element + xs:complexType (explicit attributes
    #                 in declaration order); SUBTYPE OF a schema-local
    #                 entity becomes a substitutionGroup reference.
    #   ENUMERATION → xs:simpleType with enumeration facets.
    #   SELECT      → xs:complexType with an xs:choice over the member
    #                 types (ISO 10303-28 select mapping): entity
    #                 members reference their global element
    #                 declarations, defined-type members carry their
    #                 simpleType. Declared members only — extensible
    #                 selects and cross-schema members keep the
    #                 documented v1 fallbacks.
    #   defined TYPE over a simple type → xs:simpleType restriction.
    #   attributes  → xs:element inside the complexType sequence;
    #                 LIST/SET/BAG/ARRAY → maxOccurs="unbounded".
    #
    # Built-in EXPRESS types map to XML Schema built-ins (STRING→
    # xs:string, INTEGER→xs:integer, REAL/NUMBER→xs:double,
    # BOOLEAN→xs:boolean, LOGICAL→string restriction, BINARY→
    # xs:hexBinary).
    module Xsd
      BUILTIN_TYPES = {
        "string" => "xs:string",
        "integer" => "xs:integer",
        "real" => "xs:double",
        "number" => "xs:double",
        "boolean" => "xs:boolean",
        "binary" => "xs:hexBinary",
      }.freeze

      AGGREGATES = %w[array list set bag].freeze

      module_function

      # @param schema [Model::Declarations::Schema]
      # @return [String] the serialized xs:schema document
      def format(schema)
        ctx = Moxml::Context.new
        doc = ctx.create_document
        root = doc.create_element("xs:schema")
        root.set_attributes("xmlns:xs" => "http://www.w3.org/2001/XMLSchema",
                            "elementFormDefault" => "qualified")
        doc.add_child(root)
        schema.types.to_a.each { |type| root.add_child(type_node(doc, schema, type)) }
        schema.entities.to_a.each do |entity|
          root.add_child(entity_element(doc, schema, entity))
          root.add_child(entity_type(doc, schema, entity))
        end
        doc.to_xml
      end

      def type_node(doc, schema, type)
        underlying = type.underlying_type
        if underlying.is_a?(Expressir::Model::DataTypes::Select)
          return select_type_node(doc, schema, type, underlying)
        end

        node = doc.create_element("xs:simpleType")
        node.set_attributes("name" => type.id)
        restriction = doc.create_element("xs:restriction")
        node.add_child(restriction)
        if underlying.is_a?(Expressir::Model::DataTypes::Enumeration)
          restriction.set_attributes("base" => "xs:string")
          underlying.items.to_a.each do |item|
            facet = doc.create_element("xs:enumeration")
            facet.set_attributes("value" => item.id)
            restriction.add_child(facet)
          end
        else
          restriction.set_attributes("base" => xs_type(underlying, schema))
        end
        node
      end

      # ISO 10303-28: a select type maps to a complexType choosing
      # among its member types. An extensible select with no declared
      # items gets an empty sequence — an empty xs:choice is not
      # schema-valid.
      def select_type_node(doc, schema, type, select)
        node = doc.create_element("xs:complexType")
        node.set_attributes("name" => type.id)
        container = select.items.to_a.empty? ? "xs:sequence" : "xs:choice"
        choice = doc.create_element(container)
        node.add_child(choice)
        select.items.to_a.each do |item|
          choice.add_child(select_member_element(doc, schema, item))
        end
        node
      end

      def select_member_element(doc, schema, item)
        node = doc.create_element("xs:element")
        if item.is_a?(Expressir::Model::References::SimpleReference)
          id = item.respond_to?(:base_path) && item.base_path ? base_id(item.base_path) : item.id
          member = select_member_target(schema, id)
          if member == :entity
            node.set_attributes("ref" => id)
          elsif member == :type
            node.set_attributes("name" => id, "type" => id)
          else
            node.set_attributes("name" => id, "type" => "xs:anyType")
          end
        else
          name = item.class.name.split("::").last.downcase
          node.set_attributes("name" => name,
                              "type" => BUILTIN_TYPES.fetch(name, "xs:anyType"))
        end
        node
      end

      def select_member_target(schema, id)
        if schema.entities.to_a.any? { |e| e.id.safe_downcase == id.safe_downcase }
          :entity
        elsif schema.types.to_a.any? { |t| t.id.safe_downcase == id.safe_downcase }
          :type
        else
          :unknown
        end
      end

      def entity_element(doc, schema, entity)
        node = doc.create_element("xs:element")
        node.set_attributes("name" => entity.id)
        node.set_attributes("type" => entity.id)
        parent = supertype_name(schema, entity)
        node.set_attributes("substitutionGroup" => parent) if parent
        node
      end

      def entity_type(doc, schema, entity)
        node = doc.create_element("xs:complexType")
        node.set_attributes("name" => entity.id)
        container = node
        parent = supertype_name(schema, entity)
        if parent
          content = doc.create_element("xs:complexContent")
          extension = doc.create_element("xs:extension")
          extension.set_attributes("base" => parent)
          content.add_child(extension)
          node.add_child(content)
          container = extension
        end
        sequence = doc.create_element("xs:sequence")
        container.add_child(sequence)
        explicit_attributes(entity).each do |attr|
          sequence.add_child(attribute_element(doc, schema, attr))
        end
        # EXPRESS multiple inheritance: the extension base carries the
        # first parent's chain; later parents' attributes (transitively)
        # become explicit members of the subtype's sequence.
        additional_parent_attributes(schema, entity).each do |attr|
          sequence.add_child(attribute_element(doc, schema, attr))
        end
        node
      end

      def explicit_attributes(entity)
        entity.attributes.to_a.reject do |attr|
          attr.kind == Expressir::Model::Declarations::Attribute::INVERSE ||
            (attr.respond_to?(:derive?) && attr.derive?)
        end
      end

      # Attributes contributed by multiple inheritance: every ancestor
      # reachable from the additional local supertypes (all but the
      # first), minus the first supertype's own chain — the extension
      # base already carries that. Cycle-safe.
      def additional_parent_attributes(schema, entity)
        parents = local_supertypes(schema, entity)
        return [] if parents.size <= 1

        base_chain = ancestor_set(schema, parents.first)
        seen = {}.compare_by_identity
        queue = parents.drop(1)
        attrs = []
        until queue.empty?
          current = queue.shift
          next if seen[current] || base_chain[current]

          seen[current] = true
          attrs.concat(explicit_attributes(current))
          queue.concat(local_supertypes(schema, current))
        end
        attrs
      end

      # Identity set of +entity+ and every supertype ancestor.
      def ancestor_set(schema, entity)
        seen = {}.compare_by_identity
        queue = [entity]
        until queue.empty?
          current = queue.shift
          next if seen[current]

          seen[current] = true
          queue.concat(local_supertypes(schema, current))
        end
        seen
      end

      def local_supertypes(schema, entity)
        Array(entity.subtype_of).filter_map do |ref|
          id = ref.is_a?(String) ? ref : ref.id
          next nil unless id

          schema.entities.to_a
            .find { |e| e.id.safe_downcase == id.safe_downcase }
        end
      end

      def attribute_element(doc, schema, attr)
        node = doc.create_element("xs:element")
        node.set_attributes("name" => attr.id)
        node.set_attributes("type" => xs_type(attr.type, schema))
        kind = attr.type.class.name.split("::").last.downcase
        node.set_attributes("maxOccurs" => "unbounded") if AGGREGATES.include?(kind)
        node
      end

      def xs_type(type, schema)
        if type.is_a?(Expressir::Model::References::SimpleReference)
          id = type.respond_to?(:base_path) && type.base_path ? base_id(type.base_path) : type.id
          return schema.types.to_a.any? { |t| t.id.safe_downcase == id.safe_downcase } ? id : "xs:anyType"
        end

        if type.is_a?(Expressir::Model::DataTypes::Enumeration)
          return type.id || "xs:string"
        end

        if type.respond_to?(:base_type)
          inner = type.base_type
          return xs_type(inner, schema) if inner

          return "xs:anyType"
        end

        name = type.class.name.split("::").last.downcase
        BUILTIN_TYPES.fetch(name, "xs:anyType")
      end

      def supertype_name(schema, entity)
        local_supertypes(schema, entity).first&.id
      end

      def base_id(base_path)
        parts = base_path.split(".")
        parts[-1]
      end
    end
  end
end
