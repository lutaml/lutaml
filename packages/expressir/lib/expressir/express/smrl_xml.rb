# frozen_string_literal: true

module Expressir
  module Express
    # SMRL index XML writer — the shape eengine's wo-smrl-xml.lisp
    # produces (the data layer of the STEP Module Resource Library
    # document set, expressir #276 / TODO.parity-ee 15), built with
    # moxml's node API — no hand-serialized XML strings.
    #
    # Per schema: downcased <schema> id, <schema_version> when
    # present, per-kind count comments, <use_from> per interface
    # (item-list marker), sorted <constant> names, then declarations
    # in eeng's kind order (types, entities, subtype_constraints,
    # functions, rules, procedures), alphabetical inside each kind,
    # schema-qualified names; ARM mode upcases entity names.
    #
    # format        — one document with an <smrl> root, one <schema>
    #                 element per repository schema.
    # format_schema — a standalone document whose root is the schema
    #                 element (the per-file fragment eeng emits).
    module SmrlXml
      module_function

      def format(repository, mode: :resource)
        schemas = repository.respond_to?(:schemas) ? repository.schemas : Array(repository)
        ctx = Moxml::Context.new
        doc = ctx.create_document
        root = doc.create_element("smrl")
        doc.add_child(root)
        schemas.each { |schema| root.add_child(schema_element(doc, schema, mode)) }
        doc.to_xml
      end

      def format_schema(schema, mode: :resource)
        ctx = Moxml::Context.new
        doc = ctx.create_document
        doc.add_child(schema_element(doc, schema, mode))
        doc.to_xml
      end

      def schema_element(doc, schema, mode)
        element = doc.create_element("schema")
        element.add_child(doc.create_text(schema.id.downcase))
        if schema.version&.value
          version = doc.create_element("schema_version")
          version.add_child(doc.create_text(schema.version.value))
          element.add_child(version)
        end
        counts = declaration_counts(schema)
        %i[type entity function procedure rule subtype_constraint].each do |kind|
          label = kind.to_s.split("_").map(&:upcase).join("_")
          element.add_child(doc.create_comment(Kernel.format("%-19s %4d",
                                                             label, counts[kind])))
        end
        interfaces(schema).each do |iface|
          items = iface.items.to_a.empty? ? "" : "(...)"
          add_text_element(doc, element, "use-from",
                           "#{iface.schema.id.downcase}#{items}")
        end
        constants(schema).each do |decl|
          add_text_element(doc, element, "constant", decl.id.downcase)
        end
        declarations(schema).each do |kind, decls|
          tag = kind.to_s.tr("_", "-")
          decls.each do |decl|
            add_text_element(doc, element, tag,
                             "#{schema.id}.#{name_for(kind, decl.id, mode)}")
          end
        end
        element
      end

      def add_text_element(doc, parent, tag, text)
        node = doc.create_element(tag)
        node.add_child(doc.create_text(text))
        parent.add_child(node)
      end

      # eeng's entity casing: ARM mode upcases entity names; every
      # other kind and mode is downcased.
      def name_for(kind, id, mode)
        kind == :entity && mode == :arm ? id.upcase : id.downcase
      end

      def declaration_counts(schema)
        {
          type: schema.types.to_a.size,
          entity: schema.entities.to_a.size,
          function: schema.functions.to_a.size,
          procedure: schema.procedures.to_a.size,
          rule: schema.rules.to_a.size,
          subtype_constraint: schema.subtype_constraints.to_a.size,
        }
      end

      def interfaces(schema)
        Array(schema.interfaces)
      end

      def constants(schema)
        schema.constants.to_a.sort_by(&:id)
      end

      # eeng order: types, entities, subtype_constraints, functions,
      # rules, procedures — alphabetical (byte order) inside each.
      COLL_BY_KIND = {
        types: :type,
        entities: :entity,
        subtype_constraints: :subtype_constraint,
        functions: :function,
        rules: :rule,
        procedures: :procedure,
      }.freeze

      def declarations(schema)
        COLL_BY_KIND.filter_map do |coll, kind|
          decls = schema.public_send(coll).to_a.sort_by(&:id)
          next if decls.empty?

          [kind, decls]
        end
      end
    end
  end
end
