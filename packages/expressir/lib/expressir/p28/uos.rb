# frozen_string_literal: true

module Expressir
  module P28
    # The unit of serialization faces (TODO.p28/01+02):
    # `emit` writes a P21-shaped population as a clause 9.2.2 uos
    # element and `parse` reads one back, both under the default
    # binding (clause 7) encoding rules of clause 9, so the round
    # trip is value-identical over the shared P21 value model.
    #
    # Encoding summary (clause ids cited at each rule):
    # - every instance is a by-value entity instance element
    #   (9.3.1), named by the entity id with its first letter
    #   uppercased (8.5.5 identifier conversion; 9.2.6.1 worked
    #   example `car_model` -> `Car_model`), carrying `id="id<n>"`;
    # - instance elements sit in the schema's target namespace;
    #   attribute accessor elements are unprefixed, matching the
    #   clause 9 worked example;
    # - explicit attributes become child elements (9.3.1.1):
    #   booleans `true`/`false` (9.5.2), logicals
    #   `true`/`false`/`unknown` (9.5.4), integers per xs:integer
    #   (9.5.3), enumeration items as their declared string (9.6.1),
    #   binaries as hexBinary (9.5.1), entity references as a
    #   by-reference accessor with `ref` (9.3.3), `$` omits the
    #   element (the P21 validator owns mandatory-presence
    #   findings), aggregates of simple base as whitespace LIST
    #   text (9.8.1), aggregates of entity base as one child per
    #   component, each named and referenced by its target instance
    #   (9.2.6.1 worked example `Control_points`);
    # - complex entities become `exp:complexEntity` (9.3.4) with
    #   one by-value child per supertype component.
    module Uos
      module_function

      # @param population [P21::Population]
      # @param schema [Model::Declarations::Schema]
      # @param id [String] the uos id attribute
      # @param target_namespace [String] the schema's target
      #   namespace URI (clause 7: preprocessor-chosen)
      # @param prefix [String] the namespace prefix for instance
      #   elements (clause 7: preprocessor-chosen)
      # @return [String] the serialized uos document
      def emit(population, schema, id: "uos01", schema_ref: nil,
               target_namespace: P28.default_target_namespace(schema.id),
               prefix: default_prefix(schema))
        ctx = Moxml::Context.new
        doc = ctx.create_document
        # 7.8: the uos element is a target-namespace global
        uos = doc.create_element("#{prefix}:uos")
        uos.set_attributes(
          "id" => id,
          "express" => schema.id,
          "xmlns:#{prefix}" => target_namespace,
          "xmlns:exp" => COMMON_NS,
        )
        # 9.2.6.2: the schema attribute references the express
        # element's id within an iso_10303_28 document
        uos.set_attributes("schema" => schema_ref) if schema_ref
        doc.add_child(uos)
        slots = Eval::Environment.new(schema: schema)
        population.instances.each do |pid, record|
          uos.add_child(instance_element(doc, schema, slots, prefix,
                                         population, pid, record))
        end
        doc.to_xml
      end

      # A deterministic preprocessor-chosen prefix: the initials of
      # the schema name's words (car_ownership -> "co").
      def default_prefix(schema)
        schema.id.to_s.split("_").filter_map { |word| word[0] }.join.downcase
      end

      # 8.5.5 identifier conversion: uppercase the first character.
      def element_name(express_id)
        express_id.to_s.sub(/\A[a-z]/, &:upcase)
      end

      # Part 21 keywords are stored uppercased; the XML element name
      # derives from the EXPRESS declaration id (8.5.5), falling back
      # to the downcased keyword when the schema has no declaration.
      def instance_name(entity, keyword)
        element_name(entity ? entity.id : keyword.to_s.downcase)
      end

      def instance_element(doc, schema, slots, prefix, population, pid, record)
        if record.is_a?(P21::ComplexRecord)
          return complex_entity_element(doc, schema, slots, prefix,
                                        population, pid, record)
        end

        entity = find_entity(schema, record.keyword)
        node = doc.create_element(
          "#{prefix}:#{instance_name(entity, record.keyword)}",
        )
        node.set_attributes("id" => instance_id(pid))
        record.params.each_with_index do |value, index|
          name = entity ? attribute_name(slots, entity, index) : nil
          element = attribute_value_element(doc, name, value, population,
                                            prefix)
          node.add_child(element) if element
        end
        node
      end

      # 9.3.4: one by-value child per supertype component; the id
      # rides the complexEntity element.
      def complex_entity_element(doc, schema, slots, prefix, population,
                                 pid, record)
        node = doc.create_element("exp:complexEntity")
        node.set_attributes("id" => instance_id(pid))
        record.records.each do |part|
          entity = find_entity(schema, part.keyword)
          child = doc.create_element(
            "#{prefix}:#{instance_name(entity, part.keyword)}",
          )
          part.params.each_with_index do |value, index|
            name = entity ? attribute_name(slots, entity, index) : nil
            element = attribute_value_element(doc, name, value, population,
                                              prefix)
            child.add_child(element) if element
          end
          node.add_child(child)
        end
        node
      end

      def attribute_value_element(doc, name, value, population, prefix)
        case value
        when Array then aggregate_element(doc, name, value, population,
                                          prefix)
        when P21::TypedValue then typed_element(doc, value, population,
                                                prefix)
        when :unset, :derived then nil
        when String then reference_or_string_element(doc, name, value,
                                                     population)
        when P21::Enumeration
          # Part 21 encodes logicals/booleans as .T./.F./.UNKNOWN.
          # (Part 21 7.5.3); the parser hands them to us as
          # Enumerations. Re-encode per 9.5.2/9.5.4; genuine
          # enumeration items pass through as their text (9.6.1).
          text_element(doc, name, logical_text(value.name))
        when P21::Binary
          text_element(doc, name, value.hex) # 9.5.1 hexBinary
        else
          # 9.5.2 booleans, 9.5.3/9.5.5 numerics, plain strings
          text_element(doc, name, value.to_s)
        end
      end

      # 9.3.3: a reference value is a by-reference accessor named
      # after the attribute; a string value is a text accessor.
      def reference_or_string_element(doc, name, value, _population)
        return text_element(doc, name, value) unless value.start_with?("#")

        node = doc.create_element(name ? element_name(name) : "Ref")
        node.set_attributes("ref" => instance_id(value))
        node
      end

      # 9.8.1: aggregates of simple base types are one whitespace
      # LIST text value; entity-based aggregates carry one child per
      # component, named by the component's entity type and
      # referenced (9.2.6.1 worked example `Control_points`).
      def aggregate_element(doc, name, values, population, prefix)
        node = doc.create_element(name ? element_name(name) : "List")
        if values.all? { |v| v.is_a?(String) && v.start_with?("#") }
          values.each do |ref|
            keyword = population.instances[ref]&.keyword
            child = doc.create_element(
              "#{prefix}:#{element_name(keyword ? keyword.to_s.downcase : 'ref')}",
            )
            child.set_attributes("ref" => instance_id(ref))
            node.add_child(child)
          end
        else
          node.content = values.map { |v| scalar_text(v) }.join(" ")
        end
        node
      end

      # A typed parameter (KEYWORD(values)) is emitted as the
      # capitalized keyword element wrapping its values.
      def typed_element(doc, value, population, prefix)
        node = doc.create_element(element_name(value.keyword))
        value.value.each do |item|
          element = attribute_value_element(doc, nil, item, population,
                                            prefix)
          node.add_child(element) if element
        end
        node
      end

      def text_element(doc, name, text)
        node = doc.create_element(name ? element_name(name) : "Value")
        node.content = text.to_s
        node
      end

      def logical_text(name)
        case name.to_s.upcase
        when "T" then "true"
        when "F" then "false"
        when "UNKNOWN" then "unknown"
        else name.to_s
        end
      end

      def scalar_text(value)
        case value
        when P21::Enumeration then logical_text(value.name)
        when P21::Binary then value.hex
        when :unset, :derived then ""
        else value.to_s
        end
      end

      def instance_id(pid)
        "id#{pid.to_s.delete_prefix('#')}"
      end

      # The Part 21 slot's attribute name: inherited explicit
      # attributes first (supertype closure order), the same
      # contract the P21 validator maps values by.
      def attribute_name(slots, entity, index)
        name_for_slot = slots.slots_for(entity).find { |_, slot| slot == index }
        name_for_slot&.first
      end

      def find_entity(schema, keyword)
        Array(schema.entities).find do |entity|
          entity.id&.safe_downcase == keyword&.safe_downcase
        end
      end

      # ------------------------------------------------------------------
      # The reader face (TODO.p28/02): a uos document back into a
      # P21-shaped population, inverting the writer's encodings so
      # the round trip is value-identical.
      # ------------------------------------------------------------------

      # @param xml [String] a uos document
      # @param schema [Model::Declarations::Schema]
      # @return [P21::Population]
      def parse(xml, schema)
        doc = Moxml::Context.new.parse(xml)
        uos = doc.root
        unless uos&.name == "uos"
          raise Expressir::Error, "not a uos document (root '#{uos&.name}')"
        end

        slots = Eval::Environment.new(schema: schema)
        instances = {}
        elems(uos).each do |node|
          pid = instance_pid(node)
          instances[pid] = if node.name == "complexEntity"
                             P21::ComplexRecord.new(
                               elems(node).map do |role|
                                 role_record(schema, slots, role)
                               end,
                             )
                           else
                             role_record(schema, slots, node)
                           end
        end
        P21::Population.new(instances: instances)
      end

      def instance_pid(node)
        id = attrs(node)["id"]
        unless id
          raise Expressir::Error,
                "instance element '#{node.name}' has no id"
        end

        "##{id.delete_prefix('id')}"
      end

      def role_record(schema, slots, node)
        entity = Array(schema.entities).find do |candidate|
          candidate.id&.safe_downcase == node.name.downcase
        end
        unless entity
          raise Expressir::Error,
                "element '#{node.name}' does not match any entity of " \
                "schema '#{schema.id}'"
        end

        keyword = entity.id.upcase
        mapped = {}
        elems(node).each do |accessor|
          slot_name = accessor.name.downcase
          index = slots.slots_for(entity)[slot_name]
          unless index
            raise Expressir::Error,
                  "entity '#{keyword}' has no attribute " \
                  "'#{accessor.name}'"
          end

          mapped[index] = attribute_value(schema, entity, slot_name,
                                          accessor)
        end
        size = slots.slots_for(entity).size
        params = Array.new(size) { |i| mapped[i] || :unset }
        P21::Record.new(keyword, params)
      end

      # Inverse of the writer's value encodings. Logical faces come
      # from the DECLARED type: the 9.5.2/9.5.4 texts only re-encode
      # to the Part 21 renderings when the attribute is
      # BOOLEAN/LOGICAL.
      def attribute_value(schema, entity, slot_name, accessor)
        declaration = find_attribute_decl(entity, slot_name)
        components = elems(accessor)
        if components.any?
          return components.map do |component|
            ref = attrs(component)["ref"]
            unless ref
              raise Expressir::Error,
                    "component '#{component.name}' has no ref"
            end

            "##{ref.delete_prefix('id')}"
          end
        end

        ref = attrs(accessor)["ref"] # 9.3.3 by-reference accessor
        return "##{ref.delete_prefix('id')}" if ref

        text = accessor.text
        case value_kind(schema, declaration)
        when :boolean then P21::Enumeration.new(logical_item(text, %w[T F]))
        when :logical
          P21::Enumeration.new(logical_item(text, %w[T F UNKNOWN]))
        when :enumeration then P21::Enumeration.new(text)
        when :binary then P21::Binary.new(text)
        when :number then numeric(text)
        when :list then split_list(schema, declaration, text)
        else text
        end
      end

      def logical_item(text, allowed)
        item = { "true" => "T", "false" => "F",
                 "unknown" => "UNKNOWN" }[text]
        raise Expressir::Error, "invalid logical value '#{text}'" unless
          allowed.include?(item)

        item
      end

      def value_kind(schema, declaration)
        type = declaration.respond_to?(:type) ? declaration.type : nil
        case type
        when Model::DataTypes::Boolean then :boolean
        when Model::DataTypes::Logical then :logical
        when Model::DataTypes::Binary then :binary
        when Model::DataTypes::Enumeration then :enumeration
        when Model::DataTypes::Integer, Model::DataTypes::Real,
             Model::DataTypes::Number
          :number
        else
          if type.respond_to?(:base_type) && type.base_type
            return :list # LIST/SET/BAG/ARRAY over any base (9.8.1)
          end

          resolve_defined_type(schema, type) || :string
        end
      end

      # EXPRESS builtins may arrive as DataTypes or as name
      # references; both faces resolve here.
      BUILTIN_KINDS = {
        "binary" => :binary,
        "boolean" => :boolean,
        "logical" => :logical,
        "integer" => :number,
        "real" => :number,
        "number" => :number,
        "string" => :string,
      }.freeze

      # A defined TYPE's underlying kind (the writer's enumeration
      # and aggregate faces ride on these).
      def resolve_defined_type(schema, type)
        case type
        when nil then nil
        when Model::DataTypes::Enumeration then :enumeration
        when Model::References::SimpleReference
          id = base_id_of(type)
          return BUILTIN_KINDS[id&.downcase] if BUILTIN_KINDS.key?(id&.downcase)

          decl = id &&
            Array(schema.types).find do |candidate|
              candidate.id&.safe_downcase == id
            end
          return nil unless decl

          resolve_defined_type(schema, decl.underlying_type)
        end
      end

      def base_id_of(type)
        if type.respond_to?(:base_path) && type.base_path
          type.base_path.to_s.split(".").last
        elsif type.respond_to?(:id)
          type.id
        end
      end

      def numeric(text)
        text.match?(/\A-?\d+\z/) ? text.to_i : text.to_f
      end

      # 9.8.1: whitespace LIST text; STRING components never carry
      # whitespace (clause-ruled), so splitting is lossless.
      def split_list(schema, declaration, text)
        return [] if text.empty?

        type = declaration.respond_to?(:type) ? declaration.type : nil
        base = type.respond_to?(:base_type) ? type.base_type : nil
        kind = resolve_defined_type(schema, base) || :string
        text.split(/\s+/).map do |item|
          case kind
          when :enumeration then P21::Enumeration.new(item)
          when :number then numeric(item)
          else item
          end
        end
      end

      # Direct or inherited attribute declaration by name.
      def find_attribute_decl(entity, name)
        key = name.downcase
        (entity.supertype_closure.to_a + [entity])
          .flat_map { |decl| Array(decl.attributes) }
          .find do |attr|
            attr.instance_of?(Model::Declarations::Attribute) &&
              attr.id&.safe_downcase == key
          end
      end

      def elems(node)
        node.children.grep(Moxml::Element)
      end

      def attrs(node)
        node.attributes.to_h { |a| [a.name, a.value] }
      end
    end
  end
end
