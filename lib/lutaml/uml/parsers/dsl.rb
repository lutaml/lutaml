# frozen_string_literal: true

require "parslet"
require "parslet/convenience"

module Lutaml
  module Uml
    module Parsers
      class ParsingError < Lutaml::Error; end

      # Class for parsing LutaML dsl into Lutaml::Uml::Document
      class Dsl < Parslet::Parser
        include Lutaml::Converter::DslToUml

        # @param [String] io - LutaML string representation
        #        [Hash] options - options for parsing
        #
        # @return [Lutaml::Uml::Document]
        def self.parse(io, options = {})
          new.parse(io, options)
        end

        def parse(input_file, _options = {})
          data = Lutaml::Uml::Parsers::DslPreprocessor.call(input_file)
          # https://kschiess.github.io/parslet/tricks.html#Reporter engines
          # Parslet::ErrorReporter::Deepest allows more
          # detailed display of error
          reporter = Parslet::ErrorReporter::Deepest.new
          hash = DslTransform.new.apply(super(data, reporter: reporter))
          create_uml_document(hash)
        rescue Parslet::ParseFailed => e
          raise(ParsingError,
                "#{e.message}\ncause: #{e.parse_failure_cause.ascii_tree}")
        end

        KEYWORDS = %w[
          abstract
          aggregation
          association
          association
          attribute
          bidirectional
          class
          composition
          data_type
          dependency
          diagram
          directional
          enum
          fontname
          generalizes
          include
          interface
          member
          member_type
          method
          owner
          owner_type
          primitive
          private
          protected
          public
          realizes
          static
          title
          caption
        ].freeze

        KEYWORDS.each do |keyword|
          rule("kw_#{keyword}") { str(keyword) }
        end

        rule(:spaces) { match("\s").repeat(1) }
        rule(:spaces?) { spaces.maybe }
        rule(:whitespace) do
          (match("\s") | match("	") | match("\r?\n") | match("\r") | str(";"))
            .repeat(1)
        end
        rule(:whitespace?) { whitespace.maybe }
        rule(:name) { match["a-zA-Z0-9 _-"].repeat(1) }
        rule(:newline) { str("\n") >> str("\r").maybe }
        rule(:comment_definition) do
          spaces? >> str("**") >> (newline.absent? >> any).repeat.as(:comments)
        end
        rule(:comment_multiline_definition) do
          spaces? >> str("*|") >> (str("|*").absent? >> any)
            .repeat.as(:comments) >> whitespace? >> str("|*")
        end
        rule(:class_name_chars) { match('(?:[a-zA-Z0-9 _-]|\:|\.)').repeat(1) }
        rule(:class_name) do
          class_name_chars >>
            (str("(") >>
              class_name_chars >>
              str(")")).maybe
        end
        rule(:cardinality_body_definition) do
          match['0-9\*'].as("min") >>
            str("..").maybe >>
            match['0-9\*'].as("max").maybe
        end
        rule(:cardinality) do
          str("[") >>
            cardinality_body_definition.as(:cardinality) >>
            str("]")
        end
        rule(:cardinality?) { cardinality.maybe }

        # -- attribute/Method
        rule(:kw_visibility_modifier) do
          str("+") | str("-") | str("#") | str("~")
        end

        rule(:member_static) { (kw_static.as(:static) >> spaces).maybe }
        rule(:visibility) do
          kw_visibility_modifier.as(:visibility_modifier)
        end
        rule(:visibility?) { visibility.maybe }

        rule(:method_abstract) { (kw_abstract.as(:abstract) >> spaces).maybe }
        rule(:attribute_keyword) do
          str("<<") >>
            match['a-zA-Z0-9_\-\/'].repeat(1).as(:keyword) >>
            str(">>")
        end
        rule(:attribute_keyword?) { attribute_keyword.maybe }
        rule(:attribute_type) do
          str(":") >>
            spaces? >>
            attribute_keyword? >>
            spaces? >>
            match['"\''].maybe >>
            match['a-zA-Z0-9_\- \/\+'].repeat(1).as(:type) >>
            match['"\''].maybe >>
            spaces?
        end
        rule(:attribute_type?) do
          attribute_type.maybe
        end

        rule(:attribute_name) { match['a-zA-Z0-9_\- \/\+'].repeat(1).as(:name) }
        rule(:attribute_definition) do
          (visibility?.as(:visibility) >>
            match['"\''].maybe >>
            attribute_name >>
            match['"\''].maybe >>
            attribute_type? >>
            cardinality? >>
            class_body?)
            .as(:attributes)
        end

        rule(:title_keyword) { kw_title >> spaces }
        rule(:title_text) { quoted_or_plain_text(:title) }
        rule(:title_definition) { title_keyword >> title_text }
        rule(:caption_keyword) { kw_caption >> spaces }
        rule(:caption_text) { quoted_or_plain_text(:caption) }
        rule(:caption_definition) { caption_keyword >> caption_text }

        # A quoted string (any content except its quote char or a newline) or,
        # for backward compatibility, an unquoted run of name-ish characters.
        # The quoted form lets titles/captions carry parens, slashes, etc. and
        # still round-trip through Document#to_lutaml.
        def quoted_or_plain_text(key)
          quoted_text('"', key) |
            quoted_text("'", key) |
            match['a-zA-Z0-9_\- ,.:;'].repeat(1).as(key)
        end

        def quoted_text(quote, key)
          line_break = str("\n") | str("\r")
          str(quote) >>
            ((str(quote) | line_break).absent? >> any).repeat(1).as(key) >>
            str(quote)
        end

        rule(:fontname_keyword) { kw_fontname >> spaces }
        rule(:fontname_text) do
          match['"\''].maybe >>
            match['a-zA-Z0-9_\- '].repeat(1).as(:fontname) >>
            match['"\''].maybe
        end
        rule(:fontname_definition) { fontname_keyword >> fontname_text }

        # Method
        # rule(:method_keyword) { kw_method >> spaces }
        # rule(:method_argument) { name.as(:name) >> member_type }
        # rule(:method_arguments_inner) do
        #   (method_argument >>
        #     (spaces? >> str(",") >> spaces? >> method_argument).repeat)
        #     .repeat.as(:arguments)
        # end
        # rule(:method_arguments) do
        #   (str("(") >>
        #     spaces? >>
        #     method_arguments_inner >>
        #     spaces? >>
        #     str(")"))
        #     .maybe
        # end

        # rule(:method_name) { name.as(:name) }
        # rule(:method_return_type) { member_type.maybe }
        # rule(:method_definition) do
        #   (method_abstract >>
        #     member_static >>
        #     visibility >>
        #     method_keyword >>
        #     method_name >>
        #     method_arguments >>
        #     method_return_type)
        #     .as(:method)
        # end

        # -- Association

        rule(:association_keyword) { kw_association >> spaces }

        # Association end and role names accept the same extra characters as
        # the one-line shorthand endpoints (':' and '.', for qualified names
        # like Foo::Bar), so any association the shorthand parses can be
        # re-emitted through the block form (Document#to_lutaml) and re-parsed.
        rule(:assoc_end_name) { match['a-zA-Z0-9 _\-:.'].repeat(1) }

        %w[owner member].each do |association_end_type| # rubocop:disable Metrics/BlockLength
          rule("#{association_end_type}_cardinality") do
            spaces? >>
              str("[") >>
              cardinality_body_definition
                .as("#{association_end_type}_end_cardinality") >>
              str("]")
          end
          rule("#{association_end_type}_cardinality?") do
            send(:"#{association_end_type}_cardinality").maybe
          end
          rule("#{association_end_type}_attribute_name") do
            str("#") >>
              visibility? >>
              assoc_end_name.as("#{association_end_type}_end_attribute_name")
          end
          rule("#{association_end_type}_attribute_name?") do
            send(:"#{association_end_type}_attribute_name").maybe
          end
          rule("#{association_end_type}_definition") do
            send(:"kw_#{association_end_type}") >>
              spaces >>
              assoc_end_name.as("#{association_end_type}_end") >>
              send(:"#{association_end_type}_attribute_name?") >>
              send(:"#{association_end_type}_cardinality?")
          end
          rule("#{association_end_type}_type") do
            send(:"kw_#{association_end_type}_type") >>
              spaces >>
              name.as("#{association_end_type}_end_type")
          end
        end

        rule(:association_inner_definitions) do
          owner_type |
            member_type |
            owner_definition |
            member_definition |
            comment_definition |
            comment_multiline_definition
        end
        rule(:association_inner_definition) do
          association_inner_definitions >> whitespace?
        end
        rule(:association_body) do
          spaces? >>
            str("{") >>
            whitespace? >>
            association_inner_definition.repeat.as(:members) >>
            str("}")
        end
        rule(:association_definition) do
          association_keyword >>
            name.as(:name).maybe >>
            association_body
        end

        # -- Association shorthand (one-line, PlantUML-style operators)
        #
        # Compositional operator: [left adornment] -- [right adornment]
        #   left  -> owner_end_type, right -> member_end_type
        #   *  composition   o  aggregation   <| / |>  inheritance   < / >  direct
        # Examples: A --> B | A o-- B | A o--> B | A --|> B | A *-- B | A -- B
        rule(:assoc_op_left)  { str("*") | str("o") | str("<|") | str("<") }
        rule(:assoc_op_right) { str("*") | str("o") | str("|>") | str(">") }
        rule(:assoc_op) do
          assoc_op_left.as(:op_left).maybe >>
            str("--") >>
            assoc_op_right.as(:op_right).maybe
        end
        # Operator-aware endpoint token: like a class name but whitespace-free,
        # and it stops before an operator so `Test-Class --> Other` parses while
        # `A-->B` splits correctly (a `-`/`:`/`.` is part of the name only when
        # it does not begin an operator).
        rule(:endpoint_name_chars) do
          (assoc_op.absent? >> match['a-zA-Z0-9_\-:.']).repeat(1)
        end
        %w[owner member].each do |end_type|
          rule("shortcut_#{end_type}_endpoint") do
            endpoint_name_chars.as("#{end_type}_end") >>
              (str("#") >>
                # Consume an optional visibility marker (+/-/#/~) on the role
                # name WITHOUT capturing it: the Association model has no role
                # visibility, and capturing it as :visibility_modifier on both
                # ends collides ("Duplicate subtrees") when owner and member are
                # merged into the single assoc_shortcut subtree.
                kw_visibility_modifier.maybe >>
                endpoint_name_chars.as("#{end_type}_end_attribute_name")).maybe >>
              (spaces? >>
                str("[") >>
                cardinality_body_definition.as("#{end_type}_end_cardinality") >>
                str("]")).maybe
          end
        end
        # Horizontal whitespace (space or tab) — the shared `spaces` rule only
        # matches the space byte, so the operator separator uses this to accept
        # tabs too.
        rule(:hspace) { (str(" ") | str("\t")).repeat(1) }
        # NOTE: whitespace around the operator is REQUIRED. The aggregation
        # glyph `o` is also a name character, so a spaceless form like
        # `Foo-->Bar` would mis-parse (`Foo`'s trailing `o` consumed as an
        # `o--` adornment). Mandatory whitespace makes the operator unambiguous.
        rule(:shortcut_association_definition) do
          (shortcut_owner_endpoint >>
            hspace >> assoc_op >> hspace >>
            shortcut_member_endpoint)
            .as(:assoc_shortcut)
        end

        # -- Class

        rule(:kw_class_modifier) { kw_abstract | kw_interface }

        rule(:class_modifier) do
          (kw_class_modifier.as(:modifier) >> spaces).maybe
        end
        rule(:class_keyword) { kw_class >> spaces }
        rule(:class_inner_definitions) do
          definition_body |
            attribute_definition |
            comment_definition |
            comment_multiline_definition
        end
        rule(:class_inner_definition) do
          class_inner_definitions >> whitespace?
        end
        rule(:class_body) do
          spaces? >>
            str("{") >>
            whitespace? >>
            class_inner_definition.repeat.as(:members) >>
            str("}")
        end
        rule(:class_body?) { class_body.maybe }
        rule(:class_definition) do
          class_modifier >>
            class_keyword >>
            class_name.as(:name) >>
            spaces? >>
            attribute_keyword? >>
            class_body?
        end

        # -- Definition
        rule(:definition_body) do
          spaces? >>
            str("definition") >>
            whitespace? >>
            str("{") >>
            ((str("\\") >> any) | (str("}").absent? >> any))
              .repeat.maybe.as(:definition) >>
            str("}")
        end

        # -- Enum
        rule(:enum_keyword) { kw_enum >> spaces }
        rule(:enum_inner_definitions) do
          definition_body |
            attribute_definition |
            comment_definition |
            comment_multiline_definition
        end
        rule(:enum_inner_definition) do
          enum_inner_definitions >> whitespace?
        end
        rule(:enum_body) do
          spaces? >>
            str("{") >>
            whitespace? >>
            enum_inner_definition.repeat.as(:members) >>
            str("}")
        end
        rule(:enum_body?) { enum_body.maybe }
        rule(:enum_definition) do
          enum_keyword >>
            match['"\''].maybe >>
            class_name.as(:name) >>
            match['"\''].maybe >>
            attribute_keyword? >>
            enum_body?
        end

        # -- data_type
        rule(:data_type_keyword) { kw_data_type >> spaces }
        rule(:data_type_inner_definitions) do
          definition_body |
            attribute_definition |
            comment_definition |
            comment_multiline_definition
        end
        rule(:data_type_inner_definition) do
          data_type_inner_definitions >> whitespace?
        end
        rule(:data_type_body) do
          spaces? >>
            str("{") >>
            whitespace? >>
            data_type_inner_definition.repeat.as(:members) >>
            str("}")
        end
        rule(:data_type_body?) { data_type_body.maybe }
        rule(:data_type_definition) do
          data_type_keyword >>
            match['"\''].maybe >>
            class_name.as(:name) >>
            match['"\''].maybe >>
            attribute_keyword? >>
            data_type_body?
        end

        # -- primitive
        rule(:primitive_keyword) { kw_primitive >> spaces }
        rule(:primitive_definition) do
          primitive_keyword >>
            match['"\''].maybe >>
            class_name.as(:name) >>
            match['"\''].maybe
        end

        # -- Diagram
        rule(:diagram_keyword) { kw_diagram >> spaces? }
        rule(:diagram_inner_definitions) do
          title_definition |
            caption_definition |
            fontname_definition |
            class_definition.as(:classes) |
            enum_definition.as(:enums) |
            primitive_definition.as(:primitives) |
            data_type_definition.as(:data_types) |
            association_definition.as(:associations) |
            shortcut_association_definition |
            comment_definition |
            comment_multiline_definition
        end
        rule(:diagram_inner_definition) do
          diagram_inner_definitions >> whitespace?
        end
        rule(:diagram_body) do
          spaces? >>
            str("{") >>
            whitespace? >>
            diagram_inner_definition.repeat.as(:members) >>
            str("}")
        end
        rule(:diagram_definition) do
          diagram_keyword >>
            spaces? >>
            class_name.as(:name) >>
            diagram_body >>
            whitespace?
        end
        rule(:diagram_definitions) { diagram_definition >> whitespace? }
        rule(:diagram) { whitespace? >> diagram_definition }
        # -- Root

        root(:diagram)
      end
    end
  end
end
