# frozen_string_literal: true

require "parslet"
require_relative "lml_transform"

module Lutaml
  module Uml
    module Parsers
      class Lml < Parslet::Parser
        # === Whitespace and layout ===
        rule(:space)     { str(" ") }
        rule(:space?)    { space.maybe }
        rule(:spaces)    { space.repeat(1) }
        rule(:spaces?)   { spaces.maybe }
        rule(:newline)   { match('[\r\n]') }
        rule(:eol)       { (spaces | newline) }
        rule(:eol?)      { eol.repeat }

        # === Base literals ===
        rule(:quoted_string) { str('"') >> (str('\\') >> any | str('"').absent? >> any).repeat.as(:string) >> str('"') }
        rule(:boolean)       { (str('true') | str('false')).as(:boolean) }
        rule(:number)        { match('[0-9]').repeat(1).as(:number) }
        # rule(:identifier)    { match('[a-zA-Z_]') >> match('[\w]*') }
        rule(:identifier) { match('[a-zA-Z0-9_]').repeat(1) }
        rule(:namespaced_identifier) { identifier >> (str('::') >> identifier).repeat }

        # === Values ===
        rule(:value) { quoted_string | boolean | number | namespaced_identifier.as(:identifier) | identifier.as(:identifier) }

        # === Lists ===
        rule(:list_item) { instance | value }
        rule(:list) do
          str('[') >> eol? >>
          (list_item >> spaces? >> (str(',') >> eol? >> list_item).repeat).as(:list) >> eol? >>
          str(']')
        end

        # === Attribute ===
        rule(:attribute_value) { list | value }
        rule(:attribute) do
          identifier.as(:key) >> spaces? >> str('=').maybe >> spaces? >> attribute_value.as(:value)
        end
        rule(:attributes) do
          (
            attribute_line | eol
          ).repeat.as(:attributes)
        end

        rule(:attribute_line) do
          spaces? >> attribute >> (str(',').maybe >> eol).maybe
        end

        # === Instance block ===
        rule(:instance) do
          (
            str('instance') >> spaces >>
            namespaced_identifier.as(:instance_type) >> spaces? >>
            str('{') >> eol? >>
            attributes >>
            str('}')
          ).as(:instance)
        end

        # === Require statements ===
        rule(:require_stmt) do
          str('require') >> spaces >> quoted_string.as(:require) >> eol?
        end

        rule(:require_block) do
          (require_stmt >> eol?).repeat.as(:requires)
        end

        # === Root-level instance ===
        rule(:root_instance) do
          str('instance') >> spaces >>
          identifier.as(:name) >> spaces? >>
          str('{') >> eol? >>
          attributes >>
          str('}')
        end

        # === Full document ===
        rule(:document) do
          require_block >> instance.as(:root) >> eol?
        end

        root(:document)

        class ParsingError < StandardError; end

        # Parse from file or string input, with error handling
        def self.parse(io, options = {})
          new.parse(io, options)
        end

        def self.parse_with_debug(io, options = {})
          new.parse_with_debug(io, options)
        end

        def parse_with_debug(input_file, _options = {})
          data = input_file.respond_to?(:read) ? input_file.read : input_file.to_s
          super(data)
        rescue Parslet::ParseFailed => e
          raise(ParsingError, "#{e.message}\ncause: #{e.parse_failure_cause.ascii_tree}")
        end

        def parse(input_file, _options = {})
          data = input_file.respond_to?(:read) ? input_file.read : input_file.to_s
          super(data)
        rescue Parslet::ParseFailed => e
          raise(ParsingError, "#{e.message}\ncause: #{e.parse_failure_cause.ascii_tree}")
        end
      end
    end
  end
end
