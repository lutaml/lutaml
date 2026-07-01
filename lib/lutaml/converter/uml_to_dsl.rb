# frozen_string_literal: true

module Lutaml
  module Converter
    # Serializes a Lutaml::Uml::Document back into LutaML DSL (.lutaml) text.
    #
    # This is the structural inverse of Lutaml::Converter::DslToUml: the emitted
    # text re-parses through Lutaml::Uml::Parsers::Dsl into a Document that is
    # structurally equivalent to the input (classes, attributes, enums,
    # data types, primitives and associations). It is not byte-identical to the
    # original source — whitespace is normalised and associations are emitted in
    # the explicit `association { }` block form.
    #
    # SCOPE: this targets documents that the LutaML DSL can represent (i.e.
    # DSL-authored documents, round-tripped). It deliberately does NOT emit
    # content that only originates from XMI/QEA imports and has no DSL
    # construct: package nesting (Document#packages), enum literals stored in
    # Enum#values (vs DSL enum members, which are attributes), or names/strings
    # containing characters the grammar does not accept. Exporting those is a
    # separate, fuller UML->DSL export effort.
    #
    # It also does not yet emit element comments (TopElement#comments /
    # Document#comments); comments are dropped on export. Re-emitting them is a
    # follow-up.
    module UmlToDsl
      module_function

      # Maps a model visibility to its DSL prefix symbol. "public" emits an
      # explicit `+` (the parser records implicit/no-prefix attributes as a nil
      # visibility, so emitting nothing would lose an explicit `public`).
      VISIBILITY_SYMBOL = {
        "private" => "-",
        "protected" => "#",
        "friendly" => "~",
        "public" => "+",
      }.freeze

      def convert(document)
        body = document_header(document)
        body.concat(elements_to_dsl(document))
        "#{block("diagram #{document.name || 'Document'}", body)}\n"
      end

      def document_header(document)
        header = []
        header << "title #{dsl_quote(document.title)}" if present?(document.title)
        if present?(document.caption)
          header << "caption #{dsl_quote(document.caption)}"
        end
        header << "fontname \"#{document.fontname}\"" if present?(document.fontname)
        header
      end

      # Quote a title/caption so it round-trips through the DSL grammar. Prefers
      # double quotes; switches to single quotes when the value contains a
      # double quote; if it contains both (the DSL has no escape), drops the
      # double quotes so the output still parses.
      def dsl_quote(value)
        str = value.to_s
        return "\"#{str}\"" unless str.include?('"')
        return "'#{str}'" unless str.include?("'")

        "\"#{str.delete('"')}\""
      end

      def elements_to_dsl(document) # rubocop:disable Metrics/AbcSize
        document.classes.to_a.map { |element| class_to_dsl(element) } +
          document.enums.to_a.map { |element| enum_to_dsl(element) } +
          document.data_types.to_a.map { |element| data_type_to_dsl(element) } +
          document.primitives.to_a.map { |element| "primitive #{element.name}" } +
          document.associations.to_a.map { |element| association_to_dsl(element) }
      end

      def class_to_dsl(klass)
        header = "class #{klass.name}"
        header = "#{klass.modifier} #{header}" if present?(klass.modifier)
        header += " <<#{klass.keyword}>>" if present?(klass.keyword)
        block(header, classifier_body(klass))
      end

      def enum_to_dsl(enum)
        block("enum #{enum.name}", classifier_body(enum))
      end

      def data_type_to_dsl(data_type)
        block("data_type #{data_type.name}", classifier_body(data_type))
      end

      # Shared body for class/enum/data_type: optional definition + attributes.
      def classifier_body(element)
        body = []
        body << definition_block(element.definition) if present?(element.definition)
        element.attributes.to_a.each { |attr| body << attribute_to_dsl(attr) }
        body
      end

      def attribute_to_dsl(attr)
        line = attribute_signature(attr)
        return line unless present?(attr.definition)

        # An attribute with a definition is emitted with a body block so the
        # definition round-trips (the grammar allows an attribute body).
        block(line, [definition_block(attr.definition)])
      end

      def attribute_signature(attr)
        line = "#{visibility_symbol(attr.visibility)}#{attr.name}"
        line += attribute_type_suffix(attr) if present?(attr.type)
        line += " #{cardinality_to_dsl(attr.cardinality)}" if cardinality?(attr.cardinality)
        line
      end

      def attribute_type_suffix(attr)
        suffix = ": "
        suffix += "<<#{attr.keyword}>> " if present?(attr.keyword)
        suffix + attr.type
      end

      def visibility_symbol(visibility)
        VISIBILITY_SYMBOL.fetch(visibility.to_s, "")
      end

      def association_to_dsl(assoc)
        header = present?(assoc.name) ? "association #{assoc.name}" : "association"
        block(header, association_body(assoc))
      end

      def association_body(assoc)
        [
          ("owner_type #{assoc.owner_end_type}" if present?(assoc.owner_end_type)),
          ("member_type #{assoc.member_end_type}" if present?(assoc.member_end_type)),
          ("owner #{owner_ref(assoc)}" if present?(assoc.owner_end)),
          ("member #{member_ref(assoc)}" if present?(assoc.member_end)),
        ].compact
      end

      def owner_ref(assoc)
        end_ref(assoc.owner_end, assoc.owner_end_attribute_name,
                assoc.owner_end_cardinality)
      end

      def member_ref(assoc)
        end_ref(assoc.member_end, assoc.member_end_attribute_name,
                assoc.member_end_cardinality)
      end

      def end_ref(name, attribute_name, cardinality)
        # dup: `name` is the model's own (unfrozen) string; building on a copy
        # avoids mutating assoc.owner_end / member_end in place.
        ref = name.to_s.dup
        ref += "##{attribute_name}" if present?(attribute_name)
        ref += " #{cardinality_to_dsl(cardinality)}" if cardinality?(cardinality)
        ref
      end

      def cardinality_to_dsl(cardinality)
        return "[#{cardinality.min}..#{cardinality.max}]" if present?(cardinality.max)

        "[#{cardinality.min}]"
      end

      def definition_block(text)
        # Escape the escape character itself (\) as well as the braces, so any
        # definition text round-trips through the parser's unescaping.
        escaped = text.to_s.gsub(/[\\{}]/) { |char| "\\#{char}" }
        "definition {\n#{escaped}\n}"
      end

      # Wraps `header` around an indented body. Multi-line body entries (e.g. a
      # nested definition block) are indented line by line.
      def block(header, body_entries)
        return "#{header} {}" if body_entries.empty?

        inner = body_entries
          .flat_map { |entry| entry.split("\n") }
          .map { |line| line.empty? ? line : "  #{line}" }
          .join("\n")
        "#{header} {\n#{inner}\n}"
      end

      def cardinality?(cardinality)
        cardinality && present?(cardinality.min)
      end

      def present?(value)
        value && !value.to_s.strip.empty?
      end
    end
  end
end
