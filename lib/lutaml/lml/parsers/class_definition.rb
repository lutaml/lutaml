# frozen_string_literal: true

require "parslet"

module Lutaml
  module Lml
    module Parsers
      class ClassDefinition < Parslet::Parser
        class ParsingError < StandardError; end

        # Parse from file or string input, with error handling
        def self.parse(io, options = {})
          new.parse(io, options)
        end

        def parse(input_file, _options = {})
          data = input_file.respond_to?(:read) ? input_file.read : input_file.to_s
          super(data)
        rescue Parslet::ParseFailed => e
          raise(ParsingError,
                "#{e.message}\ncause: #{e.parse_failure_cause.ascii_tree}")
        end

        # === Whitespace and layout ===
        rule(:space)     { str(" ") }
        rule(:space?)    { space.maybe }
        rule(:spaces)    { space.repeat(1) }
        rule(:spaces?)   { spaces.maybe }
        rule(:newline)   { match('[\r\n]') }
        rule(:eol)       { (spaces | newline) }
        rule(:eol?)      { eol.repeat }

        # === Base literals ===
        rule(:quoted_string) do
          str('"') >> ((str("\\") >> any) | (str('"').absent? >> any)).repeat.as(:string) >> str('"')
        end
        rule(:boolean)       { (str("true") | str("false")).as(:boolean) }
        rule(:number)        { match("[0-9]").repeat(1).as(:number) }
        rule(:variable)      { match("[a-zA-Z0-9_]").repeat(1).as(:variable) }
        rule(:reference) do
          str("reference:(") >>
            (variable >> (str(".") >> variable).repeat).as(:reference) >>
            str(")")
        end
        rule(:range) do
          (variable.as(:start) >> str("..") >> variable.as(:end)).as(:range)
        end
        rule(:identifier) { match("[a-zA-Z0-9_]").repeat(1) }
        rule(:namespaced_identifier) do
          identifier >> (str("::") >> identifier).repeat
        end

        # === Values ===
        rule(:value) do
          boolean |
            reference |
            range |
            number |
            quoted_string |
            namespaced_identifier.as(:identifier) |
            identifier.as(:identifier)
        end

        # === Lists ===
        rule(:list_item) { instance | value }
        rule(:list) do
          str("[") >> eol? >>
            (list_item >> spaces? >> str(",").maybe >> eol?).repeat.as(:list) >> eol? >>
            str("]")
        end

        # === Key-value pairs ===
        rule(:key_value_pair) do
          identifier.as(:key) >> spaces >> value.as(:value)
        end
        rule(:key_value_map) do
          str("{") >> eol? >>
            (key_value_pair >> eol).repeat.as(:key_value_map) >>
            str("}")
        end

        # === Attribute ===
        rule(:attribute_value) { list | key_value_map | value }
        rule(:attribute) do
          (spaces? >> str("#") >> match("[^\n]+").repeat.as(:comment)) |
            (identifier.as(:key) >> spaces? >> str("=").maybe >> spaces? >> attribute_value.as(:value))
        end
        rule(:attributes) do
          (
            attribute_line | eol
          ).repeat.as(:attributes)
        end

        rule(:attribute_line) do
          spaces? >> attribute >> (str(",").maybe >> eol).maybe
        end

        # === Instance block ===
        rule(:instance) do
          (
            str("instance") >> spaces >>
            namespaced_identifier.as(:instance_type) >> spaces? >>
            str("{") >> eol? >>
            ((spaces? >> instance) | attributes) >>
            str("}")
          ).as(:instance) >> eol?
        end

        # === Attribute definitions ===
        rule(:attribute_definition) do
          str("attribute") >> spaces? >> identifier.as(:name) >> spaces? >> str("{") >> eol? >>
            attributes >>
            str("}") >> eol?
        end
        rule(:attribute_definitions) do
          (spaces? >> attribute_definition).repeat(1).as(:attribute_definitions)
        end

        # === Class block ===
        rule(:parent_class) do
          str("<") >> spaces >> namespaced_identifier.as(:parent_class) >> spaces
        end

        rule(:class_block) do
          str("class") >> spaces >>
            namespaced_identifier.as(:name) >> spaces >> parent_class.maybe >>
            str("{") >> eol? >>
            (attribute_definitions | attributes) >>
            str("}")
        end
        rule(:classes) do
          (spaces? >> class_block >> eol?).repeat.as(:classes)
        end

        # === Require statements ===
        rule(:require_stmt) do
          str("require") >> spaces >> quoted_string.as(:require) >> eol?
        end

        rule(:require_block) do
          (require_stmt >> eol?).repeat.as(:requires)
        end

        # === Root-level instance ===
        rule(:root_instance) do
          str("instance") >> spaces >>
            identifier.as(:name) >> spaces? >>
            str("{") >> eol? >>
            attributes >>
            str("}")
        end

        # === Root Model block ===
        rule(:root_model) do
          str("models") >> spaces >>
            identifier.as(:name) >> spaces? >>
            str("{") >> eol? >>
            classes >> eol? >>
            str("}")
        end

        # === Full document ===
        rule(:document) do
          require_block >> (instance | root_model) >> eol?
        end

        root(:document)
      end
    end
  end
end
