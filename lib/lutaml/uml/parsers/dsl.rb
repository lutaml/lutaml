# frozen_string_literal: true

require "parslet"
require "parslet/convenience"
require "lutaml/uml/parsers/dsl_preprocessor"
require "lutaml/uml/parsers/dsl_transform"
require "lutaml/uml/node/document"
require "lutaml/converter/dsl_to_uml"

module Lutaml
  module Uml
    module Parsers
      class ParsingError < StandardError; end

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
          (str(":") >>
            spaces? >>
            attribute_keyword? >>
            spaces? >>
            match['"\''].maybe >>
            match['a-zA-Z0-9_\- \/\+'].repeat(1).as(:type) >>
            match['"\''].maybe >>
            spaces?
          )
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
        rule(:title_text) do
          match['"\''].maybe >>
            match['a-zA-Z0-9_\- ,.:;'].repeat(1).as(:title) >>
            match['"\''].maybe
        end
        rule(:title_definition) { title_keyword >> title_text }
        rule(:caption_keyword) { kw_caption >> spaces }
        rule(:caption_text) do
          match['"\''].maybe >>
            match['a-zA-Z0-9_\- ,.:;'].repeat(1).as(:caption) >>
            match['"\''].maybe
        end
        rule(:caption_definition) { caption_keyword >> caption_text }

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
              name.as("#{association_end_type}_end_attribute_name")
          end
          rule("#{association_end_type}_attribute_name?") do
            send(:"#{association_end_type}_attribute_name").maybe
          end
          rule("#{association_end_type}_definition") do
            send(:"kw_#{association_end_type}") >>
              spaces >>
              name.as("#{association_end_type}_end") >>
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
