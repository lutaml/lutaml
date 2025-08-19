# frozen_string_literal: true

require "parslet"
require "parslet/convenience"
require "lutaml/uml/parsers/dsl_preprocessor"
require "lutaml/uml/parsers/dsl_transform"
require "lutaml/uml/node/document"

module Lutaml
  module Uml
    module Parsers
      class ParsingError < StandardError; end

      # Class for parsing LutaML dsl into Lutaml::Uml::Document
      class Dsl < Parslet::Parser
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

          parsed = super(data, reporter: reporter)
          ::Lutaml::Uml::Document.new(DslTransform.new.apply(parsed))
        rescue Parslet::ParseFailed => e
          raise(ParsingError,
                "#{e.message}\ncause: #{e.parse_failure_cause.ascii_tree}")
        end

        KEYWORDS = %w[
          abstract
          aggregation
          association
          attribute
          bidirectional
          caption
          class
          collection
          composition
          condition
          data_type
          dependency
          diagram
          directional
          enum
          fontname
          generalizes
          include
          includes
          instance
          instances
          interface
          member
          member_type
          method
          models
          owner
          owner_type
          primitive
          private
          protected
          public
          realizes
          require
          static
          title
          validation
          import
          export
          format
          extends
          template
        ].freeze

        KEYWORDS.each do |keyword|
          rule("kw_#{keyword}") { whitespace? >> str(keyword) }
        end

        # === Require statements ===
        rule(:require_stmt) do
          kw_require >> spaces >> quoted_string.as(:require) >> whitespace?
        end

        rule(:require_block) do
          (require_stmt >> whitespace?).repeat.as(:requires)
        end

        rule(:require_block?) do
          require_block.maybe
        end

        rule(:quotes) { match['"\''] }
        rule(:quotes?) { quotes.maybe }
        rule(:space) { match("\s") }
        rule(:spaces) { space.repeat(1) }
        rule(:spaces?) { spaces.maybe }
        rule(:whitespace) do
          (space | match("	") | match("\r?\n") | match("\r") | str(";"))
            .repeat(1)
        end
        rule(:whitespace?) { whitespace.maybe }
        rule(:newline) { match('[\r\n]') }

        rule(:quoted_string) do
          str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"')
        end
        rule(:boolean) { (str("true") | str("false")).as(:boolean) }
        rule(:number) { match("[0-9]").repeat(1).as(:number) }
        rule(:variable) { (quoted_string | match("[a-zA-Z0-9_]").repeat(1)) }
        rule(:reference) do
          str("reference:(") >>
            (variable >> (str(".") >> variable).repeat).as(:reference) >>
            str(")")
        end
        rule(:range) do
          (variable.as(:start) >> str("..") >> variable.as(:end)).as(:range)
        end
        rule(:namespaced_identifier) do
          variable >> (str("::") >> variable).repeat
        end
        rule(:comment_definition) do
          spaces? >> (str("**") | str("#")) >> (newline.absent? >> any).repeat.as(:comments)
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
          match['0-9a-z\*'].as("min") >>
            str("..").maybe >>
            match['0-9a-z\*'].as("max").maybe
        end
        rule(:cardinality) do
          str("[") >>
            cardinality_body_definition.as(:cardinality) >>
            str("]")
        end
        rule(:cardinality?) { cardinality.maybe }

        # === Values ===
        rule(:value) do
          boolean |
            reference |
            range |
            number |
            quoted_string
        end

        # === Lists ===
        rule(:list_item) { instance | value }
        rule(:list) do
          str("[") >> whitespace? >>
            (list_item >> spaces? >> str(",").maybe >> whitespace?).repeat.as(:list) >> whitespace? >>
            str("]")
        end

        # === Key-value pairs ===
        rule(:key_value_pair) do
          variable.as(:key) >> spaces >> str("=").maybe >> spaces? >> value.as(:value)
        end
        rule(:key_value_map) do
          str("{") >> whitespace? >>
            (key_value_pair >> whitespace).repeat.as(:key_value_map) >>
            str("}")
        end

        # -- attribute/Method
        rule(:kw_visibility_modifier) do
          str("+") | str("-") | str("#") | str("~")
        end

        # === Attribute ===
        rule(:attribute_value) { list | key_value_map | value | match("[^\n]").repeat(1) }
        rule(:attribute) do
          comment_definition |
          variable.as(:key) >> spaces? >> str("+").as(:add).maybe >> str("=").maybe >> spaces? >> attribute_value.as(:value)
        end
        rule(:attributes) do
          (
            attribute_line | whitespace
          ).repeat.as(:attributes)
        end
        rule(:attribute_line) do
          spaces? >> attribute >> (str(",").maybe >> whitespace).maybe
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
          (str(":").maybe >>
            spaces? >>
            attribute_keyword? >>
            spaces? >>
            quotes? >>
            match['a-zA-Z0-9_\- \/\+'].repeat(1).as(:type) >>
            quotes? >>
            spaces?
          )
        end
        rule(:attribute_type?) do
          attribute_type.maybe
        end

        rule(:attribute_name) { match['a-zA-Z0-9_\-\/\+'].repeat(1).as(:name) }
        rule(:attribute_definition_name) do
          (quotes >> match['a-zA-Z0-9_\- \/\+'].repeat(1).as(:name) >> quotes) |
            attribute_name
        end

        rule(:attribute_definition) do
          (visibility?.as(:visibility) >>
            spaces? >>
            attribute_definition_name >>
            spaces? >>
            attribute_type? >>
            cardinality? >>
            class_body?)
            .as(:attributes)
        end

        rule(:keyword_type_argument) do
          (
            str("type").as(:name) >>
            spaces? >>
            match["[^\s\n\r]"].repeat(1).as(:value) >>
            whitespace?
          )
        end

        rule(:keyword_cardinality_argument) do
          (
            str("cardinality").as(:name) >>
            spaces? >>
            cardinality_body_definition.as(:value) >>
            whitespace?
          )
        end

        rule(:keyword_any_argument) do
          (
            spaces? >>
            match("[^\s\n\r]").repeat(1).as(:name) >>
            spaces >>
            str("=").maybe >>
            spaces? >>
            attribute_value.as(:value) >>
            whitespace?
          )
        end

        rule(:keyword_attribute_options) do
          (
            keyword_type_argument |
            keyword_cardinality_argument |
            keyword_any_argument
          ).repeat
        end

        rule(:keyword_attribute_body) do
          str("{") >>
            whitespace? >>
            keyword_attribute_options.as(:properties) >>
            whitespace? >>
            str("}")
        end

        rule(:keyword_attribute_definition) do
          (
            str("attribute") >>
            spaces >>
            attribute_name >>
            spaces? >>
            keyword_attribute_body
          ).as(:attributes)
        end

        rule(:title_keyword) { kw_title >> spaces }
        rule(:title_text) do
          quotes? >>
            match['a-zA-Z0-9_\- ,.:;'].repeat(1).as(:title) >>
            quotes?
        end
        rule(:title_definition) { title_keyword >> title_text }
        rule(:caption_keyword) { kw_caption >> spaces }
        rule(:caption_text) do
          quotes? >>
            match['a-zA-Z0-9_\- ,.:;'].repeat(1).as(:caption) >>
            quotes?
        end
        rule(:caption_definition) { caption_keyword >> caption_text }

        rule(:fontname_keyword) { kw_fontname >> spaces }
        rule(:fontname_text) do
          quotes? >>
            match['a-zA-Z0-9_\- '].repeat(1).as(:fontname) >>
            quotes?
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
              spaces? >>
              variable.as("#{association_end_type}_end_attribute_name") >>
              spaces?
          end
          rule("#{association_end_type}_attribute_name?") do
            send(:"#{association_end_type}_attribute_name").maybe
          end
          rule("#{association_end_type}_definition") do
            send(:"kw_#{association_end_type}") >>
              spaces >>
              variable.as("#{association_end_type}_end") >>
              send(:"#{association_end_type}_attribute_name?") >>
              send(:"#{association_end_type}_cardinality?")
          end
          rule("#{association_end_type}_type") do
            send(:"kw_#{association_end_type}_type") >>
              spaces >>
              variable.as("#{association_end_type}_end_type")
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
            spaces? >>
            variable.as(:name).maybe >>
            spaces? >>
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
            ((str("attribute") >> spaces).absent? >> attribute_definition) |
            keyword_attribute_definition |
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

        rule(:parent_class) do
          spaces? >> str("<") >> spaces? >> class_name_chars.as(:parent_class)
        end

        rule(:class_definition) do
          class_modifier >>
            class_keyword >>
            class_name.as(:name) >>
            parent_class.maybe >>
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

        # === Instance block ===
        rule(:instance) do
          keyword_instance | class_instance
        end

        rule(:keyword_instance) do
          (
            kw_instance >> spaces >>
            namespaced_identifier.as(:instance_type) >> spaces? >>
            str("{") >> whitespace? >>
            ((spaces? >> instance) | attributes) >>
            str("}")
          ).as(:instance) >> whitespace?
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
            quotes? >>
            class_name.as(:name) >>
            quotes? >>
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
            quotes? >>
            class_name.as(:name) >>
            quotes? >>
            attribute_keyword? >>
            data_type_body?
        end

        # -- primitive
        rule(:primitive_keyword) { kw_primitive >> spaces }
        rule(:primitive_definition) do
          primitive_keyword >>
            quotes? >>
            class_name.as(:name) >>
            quotes?
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

        rule(:models) do
          kw_models >> whitespace? >>
            variable.as(:name) >> whitespace? >> str("{") >>
            class_definition.repeat.as(:classes) >> whitespace? >>
            str("}") >> whitespace?
        end

        # === Collection block inside instances ===
        rule(:collections) do
          collection.repeat.as(:collections)
        end

        rule(:collection) do
          kw_collection >> spaces >> quoted_string.as(:name) >> spaces? >>
            str("{") >> whitespace? >>
            includes.maybe >> whitespace? >>
            validation.maybe >> whitespace? >>
            str("}") >> whitespace?
        end

        # === Includes block ===
        rule(:includes) do
          kw_includes >> spaces? >> list.as(:includes)
        end

        # === Validation block ===
        rule(:validation) do
          kw_validation >> spaces? >> str("{") >> whitespace? >>
            condition.repeat.as(:validations) >>
            str("}")
        end

        rule(:condition) do
          kw_condition >> spaces >> quoted_string.as(:condition) >> whitespace?
        end

        # === Import block ===
        rule(:import) do
          kw_import >> spaces? >> str("{") >> whitespace? >>
            import_definition.repeat.as(:imports) >>
          str("}") >> whitespace?
        end

        rule(:import_definition) do
          match("[^\s\n\r]").repeat(1).as(:format_type) >> spaces? >> quoted_string.as(:file) >> whitespace? >>
            str("{") >> whitespace? >>
            attributes >> whitespace? >>
            str("}") >> whitespace?
        end

        # === Instances block with collections, import, export ===
        rule(:instances) do
          kw_instances >> whitespace? >>
            str("{") >> whitespace? >>
            instances_body.maybe >>
            str("}") >> whitespace?
        end

        rule(:instances_body) do
          (instances_member >> whitespace?).repeat.as(:instances)
        end

        rule(:instances_member) do
          import | collection.as(:collection) | export | instance
        end

        rule(:class_instance) do
          (variable.as(:instance_type) >> whitespace? >> quoted_string.as(:name) >> whitespace? >>
            (kw_extends >> whitespace? >> quoted_string.as(:parent) >> whitespace?).maybe >>
             str("{") >> whitespace? >>
            lml_instance_body.maybe >>
            str("}")).as(:instance) >> whitespace?
        end

        rule(:lml_instance_body) do
          (lml_instance_members >> whitespace?)
        end

        rule(:instance_template) do
          kw_template >> whitespace? >> str("{") >> whitespace? >>
            attributes >> whitespace? >>
            str("}") >> whitespace?
        end

        rule(:lml_instance_members) do
          instance_template.as(:template) | attributes
        end

        # === Export block ===
        rule(:export) do
          kw_export >> whitespace? >> str("{") >> whitespace? >>
            (export_format >> whitespace?).repeat(1).as(:exports) >>
            str("}") >> whitespace?
        end

        rule(:export_format) do
          kw_format >> spaces >> variable.as(:format_type) >> whitespace? >> str("{") >> whitespace? >>
            attributes >>
            str("}") >> whitespace?
        end

        # -- Root
        rule(:diagram) { require_block? >> (models | diagram_definitions | instances | instance) }

        root(:diagram)
      end
    end
  end
end
