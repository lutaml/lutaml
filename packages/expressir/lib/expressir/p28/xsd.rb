# frozen_string_literal: true

module Expressir
  module P28
    # The default-binding derived XML schema (TODO.p28/03): an EXPRESS
    # schema rendered per ISO 10303-28:2007 clause 7 so that clause 9
    # instance documents (P28::Uos.emit) validate against it.
    #
    # Normative anchors, per rule:
    # - 7.7/7.7.3: one xs:schema with targetNamespace; xmlns for the
    #   target namespace, xs and the Base XML Schema; if present,
    #   elementFormDefault/attributeFormDefault shall be "unqualified"
    #   — which is what makes the clause 9 instance shape (qualified
    #   instance elements, unqualified accessors) validate.
    # - 7.7.4: xs:import for the Base XML Schema (exp:) and for each
    #   interfaced schema.
    # - 7.1.2: identifiers map with the initial letter upper case and
    #   all other letters lower case.
    # - 7.2: BINARY → exp:hexBinary (base-schema complexType with
    #   extraBits), the other simple types per 7.2.1.
    # - 7.3: defined types → named simpleType/complexType per the
    #   underlying type; enumerations keep their EXPRESS item texts.
    # - 7.6.2: explicit attributes only — DERIVEd and INVERSE
    #   attributes are not mapped.
    # - 7.6.4: the entity complexType extends exp:Entity, holds the
    #   accessor declarations of the whole supertype closure (union,
    #   redeclarations winning) inside xs:all, and is abstract when
    #   the entity is ABSTRACT.
    # - 7.6.5/7.5.3: one global instance element per entity, in the
    #   substitution group headed by exp:Entity.
    # - 7.8: a context-schema specific uos element declaration.
    #
    # v1 boundary, stated: constrained widths/precisions do not emit
    # facet restrictions; SELECT accessors map their declared members
    # as a choice (the full 7.4 select machinery, including
    # extensible-select fallbacks, is future work); cross-schema
    # supertypes raise rather than silently dropping attributes.
    module Xsd
      XS = "http://www.w3.org/2001/XMLSchema"

      module_function

      # The Base XML Schema (annex C) components the default binding
      # relies on, emitted from the normative snippets in clause 7
      # (7.5.3.1 exp:Entity, 7.2.1.1 exp:hexBinary) and the logical
      # value domain of 9.5.4.
      def base_schema
        <<~XSD
          <xs:schema xmlns:xs="#{XS}"
                     targetNamespace="#{COMMON_NS}"
                     xmlns:exp="#{COMMON_NS}"
                     elementFormDefault="qualified"
                     attributeFormDefault="unqualified">
            <xs:attributeGroup name="instanceAttributes">
              <xs:attribute name="id" type="xs:ID" use="optional"/>
            </xs:attributeGroup>
            <xs:complexType name="Entity" abstract="true">
              <xs:attribute name="href" type="xs:anyURI" use="optional"/>
              <xs:attribute name="ref" type="xs:IDREF" use="optional"/>
              <xs:attribute name="proxy" type="xs:IDREF" use="optional"/>
              <xs:attribute name="edo" type="xs:anyURI" use="optional"/>
              <xs:attributeGroup ref="exp:instanceAttributes"/>
            </xs:complexType>
            <xs:element name="Entity" type="exp:Entity" abstract="true"/>
            <xs:complexType name="hexBinary">
              <xs:simpleContent>
                <xs:extension base="xs:hexBinary">
                  <xs:attribute name="extraBits" type="xs:integer"
                                use="optional"/>
                </xs:extension>
              </xs:simpleContent>
            </xs:complexType>
            <xs:simpleType name="logical">
              <xs:restriction base="xs:string">
                <xs:enumeration value="true"/>
                <xs:enumeration value="false"/>
                <xs:enumeration value="unknown"/>
              </xs:restriction>
            </xs:simpleType>
            <xs:complexType name="complexEntity">
              <xs:sequence>
                <xs:any namespace="##other" processContents="lax"
                        maxOccurs="unbounded"/>
              </xs:sequence>
              <xs:attributeGroup ref="exp:instanceAttributes"/>
            </xs:complexType>
            <xs:element name="complexEntity" type="exp:complexEntity"/>
            <xs:complexType name="uos" abstract="true">
              <xs:attribute name="id" type="xs:ID" use="optional"/>
              <xs:attribute name="express" type="xs:string"
                            use="optional"/>
              <xs:attribute name="edo" type="xs:anyURI" use="optional"/>
            </xs:complexType>
            <xs:element name="uos" type="exp:uos" abstract="true"/>
            <xs:element name="edokey" type="exp:Entity"/>
          </xs:schema>
        XSD
      end

      # @param schema [Model::Declarations::Schema]
      # @param target_namespace [String] the 7.7.2 namespace URI
      # @param prefix [String] the preprocessor-chosen target-namespace
      #   prefix (7.7.1)
      # @param configuration [Configuration] clause 8 directives over
      #   the default binding (naming convention, target namespace,
      #   explicit renames)
      # @return [String] the serialized derived XML schema
      def format(schema, target_namespace: nil,
                 prefix: Uos.default_prefix(schema),
                 base_schema_location: "iso-10303-28-base.xsd",
                 inline_base: false, configuration: Configuration.empty)
        target_namespace ||= configuration.target_namespace ||
          P28.default_target_namespace(schema.id)
        ctx = Moxml::Context.new
        doc = ctx.create_document
        root = doc.create_element("xs:schema")
        root.set_attributes(
          "targetNamespace" => target_namespace,
          "xmlns:#{prefix}" => target_namespace,
          "xmlns:xs" => XS,
          "xmlns:exp" => COMMON_NS,
          "elementFormDefault" => "unqualified",
          "attributeFormDefault" => "unqualified",
        )
        doc.add_child(root)
        # inline_base: toolchains that cannot resolve xs:import from
        # an in-memory compilation get the base components inlined
        # (same content, local names); the default emits the
        # normative 7.7.4 import.
        if inline_base
          inline_base_components(doc, prefix)
        else
          root.add_child(import_node(doc, COMMON_NS, base_schema_location))
        end
        schema.types.to_a.each do |type|
          node = defined_type_node(doc, schema, prefix, type, inline_base,
                                   configuration)
          root.add_child(node) if node
        end
        schema.entities.to_a.each do |entity|
          root.add_child(entity_type_node(doc, schema, prefix, entity,
                                          inline_base, configuration))
          root.add_child(entity_element_node(doc, prefix, entity, inline_base,
                                             configuration))
        end
        uos_node(doc, schema, prefix, inline_base).each do |node|
          root.add_child(node)
        end
        doc.to_xml
      end

      # exp: in the normative import form; the target-namespace
      # prefix when inlined — an unprefixed QName in a schema with a
      # targetNamespace resolves to the empty namespace (XSD QName
      # rules), which stricter engines reject at compile time.
      def exp_name(name, inline, prefix = "exp")
        inline ? "#{prefix}:#{name}" : "exp:#{name}"
      end

      def inline_base_components(doc, prefix)
        root = doc.root
        group = doc.create_element("xs:attributeGroup")
        group.set_attributes("name" => "instanceAttributes")
        id_attr = doc.create_element("xs:attribute")
        id_attr.set_attributes("name" => "id", "type" => "xs:ID",
                               "use" => "optional")
        group.add_child(id_attr)
        root.add_child(group)
        entity = doc.create_element("xs:complexType")
        entity.set_attributes("name" => "Entity", "abstract" => "true")
        { "href" => "xs:anyURI", "ref" => "xs:IDREF",
          "proxy" => "xs:IDREF", "edo" => "xs:anyURI" }.each do |name, type|
          attr = doc.create_element("xs:attribute")
          attr.set_attributes("name" => name, "type" => type,
                              "use" => "optional")
          entity.add_child(attr)
        end
        group_ref = doc.create_element("xs:attributeGroup")
        group_ref.set_attributes("ref" => exp_name("instanceAttributes", true,
                                                   prefix))
        entity.add_child(group_ref)
        root.add_child(entity)
        entity_el = doc.create_element("xs:element")
        entity_el.set_attributes(
          "name" => "Entity", "type" => exp_name("Entity", true, prefix),
          "abstract" => "true"
        )
        root.add_child(entity_el)
        hex = doc.create_element("xs:complexType")
        hex.set_attributes("name" => "hexBinary")
        content = doc.create_element("xs:simpleContent")
        extension = doc.create_element("xs:extension")
        extension.set_attributes("base" => "xs:hexBinary")
        extra = doc.create_element("xs:attribute")
        extra.set_attributes("name" => "extraBits", "type" => "xs:integer",
                             "use" => "optional")
        extension.add_child(extra)
        content.add_child(extension)
        hex.add_child(content)
        root.add_child(hex)
        logical = doc.create_element("xs:simpleType")
        logical.set_attributes("name" => "logical")
        restriction = doc.create_element("xs:restriction")
        restriction.set_attributes("base" => "xs:string")
        %w[true false unknown].each do |value|
          facet = doc.create_element("xs:enumeration")
          facet.set_attributes("value" => value)
          restriction.add_child(facet)
        end
        logical.add_child(restriction)
        root.add_child(logical)
        complex = doc.create_element("xs:complexType")
        complex.set_attributes("name" => "complexEntity")
        seq = doc.create_element("xs:sequence")
        any = doc.create_element("xs:any")
        any.set_attributes("namespace" => "##targetNamespace",
                           "processContents" => "lax",
                           "maxOccurs" => "unbounded")
        seq.add_child(any)
        complex.add_child(seq)
        group_ref2 = doc.create_element("xs:attributeGroup")
        group_ref2.set_attributes("ref" => exp_name("instanceAttributes", true,
                                                    prefix))
        complex.add_child(group_ref2)
        root.add_child(complex)
        complex_el = doc.create_element("xs:element")
        complex_el.set_attributes(
          "name" => "complexEntity",
          "type" => exp_name("complexEntity", true, prefix),
        )
        root.add_child(complex_el)
        # distinct name: the derived schema declares its own uos type
        # extending this carrier, so a second global "uos" here would
        # be a duplicate declaration
        uos_type = doc.create_element("xs:complexType")
        uos_type.set_attributes("name" => "uos_base", "abstract" => "true")
        %w[id express edo].zip(%w[xs:ID xs:string xs:anyURI])
          .each do |(name, type)|
          attr = doc.create_element("xs:attribute")
          attr.set_attributes("name" => name, "type" => type,
                              "use" => "optional")
          uos_type.add_child(attr)
        end
        root.add_child(uos_type)
        uos_el = doc.create_element("xs:element")
        uos_el.set_attributes("name" => "uos_base", "type" => "uos_base",
                              "abstract" => "true")
        root.add_child(uos_el)
        edokey = doc.create_element("xs:element")
        edokey.set_attributes("name" => "edokey",
                              "type" => exp_name("Entity", true, prefix))
        root.add_child(edokey)
      end

      def import_node(doc, namespace, location)
        node = doc.create_element("xs:import")
        node.set_attributes("namespace" => namespace,
                            "schemaLocation" => location)
        node
      end

      # 7.1.2 identifier mapping, configured per clause 8: the
      # naming-convention (initial-upper default) then the explicit
      # rename, looked up by kind ("types", "entities") and pair
      # ("Entity.attr" for attributes).
      def mapped(express_id, config = nil, kind = nil, scope: nil)
        base = case config&.naming_convention
               when "camel-case"
                 express_id.to_s.split("_").each_with_index.map do |part, i|
                   i.zero? ? part : part.sub(/\A./, &:upcase)
                 end.join
               when "preserve-case"
                 express_id.to_s
               else
                 express_id.to_s.sub(/\A./, &:upcase)
               end
        return base if config.nil?

        renamed =
          case kind
          when :type then config.scopes.types[express_id.to_s]
          when :entity then config.scopes.entities[express_id.to_s]
          when :attribute then config.scopes.attributes[scope]
          end
        renamed || base
      end

      # 7.3: defined types over simple/enum/aggregates.
      def defined_type_node(doc, schema, prefix, type, inline, config = nil)
        underlying = type.underlying_type
        case kind_of(schema, underlying)
        when :enumeration
          simple_type_node(doc, prefix, mapped(type.id, config, :type),
                           "xs:string") do |restriction|
            underlying.items.to_a.each do |item|
              facet = doc.create_element("xs:enumeration")
              facet.set_attributes("value" => item.id.to_s)
              restriction.add_child(facet)
            end
          end
        when :simple
          simple_type_node(doc, prefix, mapped(type.id, config, :type),
                           simple_type_name(schema, underlying, inline))
        when :aggregate
          list_type_node(doc, schema, prefix, type.id, underlying, inline,
                         config)
        end
      end

      def simple_type_node(doc, _prefix, express_id, base)
        node = doc.create_element("xs:simpleType")
        node.set_attributes("name" => express_id.to_s)
        restriction = doc.create_element("xs:restriction")
        restriction.set_attributes("base" => base)
        node.add_child(restriction)
        if block_given?
          yield restriction
        end
        node
      end

      # 7.3.2/8.2.2.3: aggregates of simple base types derive from
      # xs:list over the base's item type.
      def list_type_node(doc, schema, _prefix, express_id, aggregate, inline,
                         config = nil)
        node = doc.create_element("xs:simpleType")
        node.set_attributes("name" => mapped(express_id, config, :type))
        list = doc.create_element("xs:list")
        base = aggregate.base_type
        list.set_attributes(
          "itemType" => simple_type_name(schema, base, inline, config),
        )
        node.add_child(list)
        node
      end

      # 7.6.4: extension of exp:Entity, xs:all over the closure
      # union, abstract per ABSTRACT SUPERTYPE.
      def entity_type_node(doc, schema, prefix, entity, inline, config = nil)
        node = doc.create_element("xs:complexType")
        node.set_attributes("name" => mapped(entity.id, config, :entity))
        node.set_attributes("abstract" => "true") if entity.abstract
        content = doc.create_element("xs:complexContent")
        extension = doc.create_element("xs:extension")
        extension.set_attributes("base" => exp_name("Entity", inline, prefix))
        all_node = doc.create_element("xs:all")
        closure_attributes(entity).each do |attribute|
          scope = "#{entity.id}.#{attribute.id}"
          accessor = accessor_node(doc, schema, prefix, attribute, inline,
                                   config, scope)
          all_node.add_child(accessor) if accessor
        end
        extension.add_child(all_node)
        content.add_child(extension)
        node.add_child(content)
        node
      end

      # 7.6.5: the global instance element, in the exp:Entity
      # substitution group.
      def entity_element_node(doc, prefix, entity, inline, config = nil)
        name = mapped(entity.id, config, :entity)
        node = doc.create_element("xs:element")
        node.set_attributes(
          "name" => name,
          "type" => "#{prefix}:#{name}",
          "substitutionGroup" => exp_name("Entity", inline, prefix),
        )
        node
      end

      # 7.6.3: one accessor element per mapped attribute; OPTIONAL
      # attributes are minOccurs="0"; aggregates carry their
      # occurrence bounds.
      #
      # Entity-typed accessors carry the REF form (exp:Entity —
      # content-free, the ref/href IDREF attributes): a P21
      # entity-valued position holds a reference (#N), never inline
      # content, and the full validated form stays on the GLOBAL
      # entity element (substitutionGroup exp:Entity). Typing the
      # accessor with the entity's own complexType demanded that
      # content inside by-reference occurrences — `<Widget ref="id2"/>`
      # could not validate (#565, exposed by leptris 1.9.383 fixing
      # the empty-instance bypass #1860).
      def accessor_node(doc, schema, prefix, attribute, inline, config = nil,
                        scope = nil)
        type = attribute.type
        optional = attribute.respond_to?(:optional) && attribute.optional
        kind = kind_of(schema, type)
        node = doc.create_element("xs:element")
        node.set_attributes("name" => mapped(attribute.id, config, :attribute,
                                             scope: scope))
        node.set_attributes("minOccurs" => "0") if optional
        case kind
        when :entity
          # exp:Entity is abstract — an element cannot use it as its
          # type directly (libxml2 rejects the schema); the concrete
          # ref form is an anonymous empty extension carrying the
          # base's ref/href attributes.
          node.add_child(ref_form_node(doc, inline, prefix))
        when :entity_aggregate
          node.add_child(aggregate_content_node(doc, schema, prefix, type,
                                                config, inline: inline))
        when :aggregate
          node.add_child(inline_list_node(doc, schema, type, inline))
        when :select
          raise Expressir::Error,
                "SELECT accessor '#{attribute.id}' is outside the v1 " \
                "default derivation (TODO.p28/03 boundary)"
        else
          node.set_attributes("type" => simple_type_name(schema, type, inline,
                                                         config))
        end
        node
      end

      # An aggregate declared directly on the attribute (no defined
      # TYPE): an inline xs:list over the base item type.
      def inline_list_node(doc, schema, aggregate, inline)
        base = aggregate.base_type
        node = doc.create_element("xs:simpleType")
        list = doc.create_element("xs:list")
        list.set_attributes("itemType" => simple_type_name(schema, base, inline))
        node.add_child(list)
        node
      end

      # Aggregates of entity base: the accessor wraps unqualified
      # component elements typed by the component entity (9.2.6.1
      # worked example shape).
      def aggregate_content_node(doc, schema, prefix, aggregate, config = nil,
                                 inline: false)
        base = aggregate.base_type
        target = entity_id_of(schema, base)
        name = mapped(target, config, :entity)
        content = doc.create_element("xs:complexType")
        sequence = doc.create_element("xs:sequence")
        component = doc.create_element("xs:element")
        # Aggregate members hold REFERENCES to entity instances
        # (P21 #N ids), so the component element carries the
        # content-free ref form (exp:Entity) — the full validated
        # form stays on the global entity element (#565).
        component.set_attributes(
          "name" => name,
          "minOccurs" => "0",
          "maxOccurs" => "unbounded",
        )
        component.add_child(ref_form_node(doc, inline, prefix))
        sequence.add_child(component)
        content.add_child(sequence)
        content
      end

      # The concrete ref form: an anonymous empty extension of
      # exp:Entity — content-free, carrying the base's ref/href
      # attributes. Entity-valued positions in a P21 instance hold
      # references (#N ids), never inline content (#565).
      def ref_form_node(doc, inline, prefix)
        content = doc.create_element("xs:complexContent")
        extension = doc.create_element("xs:extension")
        extension.set_attributes("base" => exp_name("Entity", inline, prefix))
        content.add_child(extension)
        content
      end

      # 7.8: the context-schema specific uos element — in the
      # exp:uos substitution group, extending the exp:uos carrier,
      # with a repeating choice over the exp:Entity substitution
      # head (every entity instance element) and the complexEntity
      # carrier.
      def uos_node(doc, _schema, prefix, inline)
        # inline mode names the carrier uos_base (the derived type
        # is uos); the imported base schema names it exp:uos
        carrier = inline ? "#{prefix}:uos_base" : "exp:uos"
        element = doc.create_element("xs:element")
        element.set_attributes(
          "name" => "uos",
          "type" => "#{prefix}:uos",
          "substitutionGroup" => carrier,
        )
        node = doc.create_element("xs:complexType")
        node.set_attributes("name" => "uos")
        complex_content = doc.create_element("xs:complexContent")
        extension = doc.create_element("xs:extension")
        extension.set_attributes("base" => carrier)
        choice = doc.create_element("xs:choice")
        choice.set_attributes("minOccurs" => "0", "maxOccurs" => "unbounded")
        head = doc.create_element("xs:element")
        head.set_attributes("ref" => exp_name("Entity", inline, prefix))
        choice.add_child(head)
        complex = doc.create_element("xs:element")
        complex.set_attributes("ref" => exp_name("complexEntity", inline, prefix))
        choice.add_child(complex)
        extension.add_child(choice)
        complex_content.add_child(extension)
        node.add_child(complex_content)
        [element, node]
      end

      def closure_attributes(entity)
        (entity.supertype_closure.to_a + [entity])
          .flat_map { |decl| Array(decl.attributes) }
          .select { |attr| attr.instance_of?(Model::Declarations::Attribute) }
          .reject do |attr|
            attr.respond_to?(:kind) &&
              [Model::Declarations::Attribute::DERIVED,
               Model::Declarations::Attribute::INVERSE].include?(attr.kind)
          end
          .uniq { |attr| attr.id&.safe_downcase }
      end

      # 7.2/7.3 kind resolution over the type face.
      def kind_of(schema, type)
        case type
        when Model::DataTypes::Enumeration
          :enumeration
        when Model::DataTypes::Boolean, Model::DataTypes::Logical,
             Model::DataTypes::Binary, Model::DataTypes::Integer,
             Model::DataTypes::Real, Model::DataTypes::Number,
             Model::DataTypes::String
          :simple
        when Model::DataTypes::Select
          :select
        else
          if type.respond_to?(:base_type) && type.base_type
            base = type.base_type
            if entity_type?(schema, base)
              :entity_aggregate
            else
              :aggregate
            end
          elsif entity_type?(schema, type)
            :entity
          else
            defined_kind(schema, type)
          end
        end
      end

      def defined_kind(schema, type)
        return :string unless type.is_a?(Model::References::SimpleReference)

        id = type.respond_to?(:base_path) && type.base_path ? type.base_path.to_s.split(".").last : type.id
        decl = id &&
          Array(schema.types).find do |candidate|
            candidate.id&.safe_downcase == id
          end
        return :string unless decl

        kind_of(schema, decl.underlying_type)
      end

      def entity_type?(schema, type)
        return false unless type.is_a?(Model::References::SimpleReference)

        id = type.respond_to?(:base_path) && type.base_path ? type.base_path.to_s.split(".").last : type.id
        id && Array(schema.entities)
          .any? { |entity| entity.id&.safe_downcase == id }
      end

      def entity_id_of(schema, type)
        id = type.respond_to?(:base_path) && type.base_path ? type.base_path.to_s.split(".").last : type.id
        decl = Array(schema.entities).find do |entity|
          entity.id&.safe_downcase == id
        end
        raise Expressir::Error, "no entity '#{id}' in '#{schema.id}'" unless decl

        decl.id
      end

      def type_id(type)
        type.respond_to?(:base_path) && type.base_path ? type.base_path.to_s.split(".").last : type.id
      end

      # 7.2.1: the XML Schema data type for a simple/defined face.
      def simple_type_name(_schema, type, inline, config = nil)
        case type
        when Model::DataTypes::Boolean then "xs:boolean"
        when Model::DataTypes::Logical then exp_name("logical", inline)
        when Model::DataTypes::Binary then exp_name("hexBinary", inline)
        when Model::DataTypes::Integer then "xs:integer"
        when Model::DataTypes::Real, Model::DataTypes::Number then "xs:double"
        when Model::DataTypes::String then "xs:string"
        when Model::DataTypes::Enumeration
          raise Expressir::Error,
                "anonymous enumeration type needs a defined TYPE wrapper"
        else
          if type.respond_to?(:base_type) && type.base_type
            return "xs:string" # xs:list-derived aggregate
          end

          mapped(type_id(type), config, :type).to_s
        end
      end
    end
  end
end
