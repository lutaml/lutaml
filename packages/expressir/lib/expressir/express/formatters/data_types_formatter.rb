module Expressir
  module Express
    module Formatters
      module DataTypesFormatter
        def self.included(base)
          base.register_formatter Model::DataTypes::Aggregate,
                                  :format_data_types_aggregate
          base.register_formatter Model::DataTypes::Array,
                                  :format_data_types_array
          base.register_formatter Model::DataTypes::Bag, :format_data_types_bag
          base.register_formatter Model::DataTypes::Binary,
                                  :format_data_types_binary
          base.register_formatter Model::DataTypes::Boolean,
                                  :format_data_types_boolean
          base.register_formatter Model::DataTypes::Enumeration,
                                  :format_data_types_enumeration
          base.register_formatter Model::DataTypes::EnumerationItem,
                                  :format_data_types_enumeration_item
          base.register_formatter Model::DataTypes::GenericEntity,
                                  :format_data_types_generic_entity
          base.register_formatter Model::DataTypes::Generic,
                                  :format_data_types_generic
          base.register_formatter Model::DataTypes::Integer,
                                  :format_data_types_integer
          base.register_formatter Model::DataTypes::List,
                                  :format_data_types_list
          base.register_formatter Model::DataTypes::Logical,
                                  :format_data_types_logical
          base.register_formatter Model::DataTypes::Number,
                                  :format_data_types_number
          base.register_formatter Model::DataTypes::Real,
                                  :format_data_types_real
          base.register_formatter Model::DataTypes::Select,
                                  :format_data_types_select
          base.register_formatter Model::DataTypes::Set, :format_data_types_set
          base.register_formatter Model::DataTypes::String,
                                  :format_data_types_string
        end

        def format_data_types_aggregate(node)
          [
            "AGGREGATE",
            *if node.base_type
               [
                 " ",
                 "OF",
                 " ",
                 format(node.base_type),
               ]
             end,
          ].join
        end

        def format_data_types_array(node)
          [
            "ARRAY",
            *if node.bound1 && node.bound2
               [
                 " ",
                 "[",
                 format(node.bound1),
                 ":",
                 format(node.bound2),
                 "]",
               ].join
             end,
            " ",
            "OF",
            *if node.optional
               [
                 " ",
                 "OPTIONAL",
               ].join
             end,
            *if node.unique
               [
                 " ",
                 "UNIQUE",
               ].join
             end,
            " ",
            format(node.base_type),
          ].join
        end

        def format_data_types_bag(node)
          [
            "BAG",
            *if node.bound1 && node.bound2
               [
                 " ",
                 "[",
                 format(node.bound1),
                 ":",
                 format(node.bound2),
                 "]",
               ].join
             end,
            " ",
            "OF",
            " ",
            format(node.base_type),
          ].join
        end

        def format_data_types_binary(node)
          [
            "BINARY",
            *if node.width
               [
                 " ",
                 "(",
                 format(node.width),
                 ")",
               ].join
             end,
            *if node.fixed
               [
                 " ",
                 "FIXED",
               ].join
             end,
          ].join
        end

        def format_data_types_boolean(_node)
          "BOOLEAN"
        end

        def format_data_types_enumeration(node)
          indent_char = self.class.const_get(:INDENT_CHAR)
          [
            *if node.extensible
               [
                 "EXTENSIBLE",
                 " ",
               ].join
             end,
            "ENUMERATION",
            *if node.based_on
               [
                 " ",
                 "BASED_ON",
                 " ",
                 format(node.based_on),
                 *if node.items&.length&.positive?
                    item_indent = indent_char * "(".length
                    [
                      " ",
                      "WITH",
                      "\n",
                      indent([
                        "(",
                        node.items.map do |x|
                          format(x)
                        end.join(",\n#{item_indent}"),
                        ")",
                      ].join),
                    ].join
                  end,
               ].join
             else
               [
                 *if node.items&.length&.positive?
                    item_indent = indent_char * "(".length
                    [
                      " ",
                      "OF",
                      "\n",
                      indent([
                        "(",
                        node.items.map do |x|
                          format(x)
                        end.join(",\n#{item_indent}"),
                        ")",
                      ].join),
                    ].join
                  end,
               ].join
             end,
          ].join
        end

        def format_data_types_enumeration_item(node)
          node.id
        end

        def format_data_types_generic_entity(node)
          [
            "GENERIC_ENTITY",
            *if node.id
               [
                 " : ",
                 node.id,
               ]
             end,
          ].join
        end

        def format_data_types_generic(node)
          [
            "GENERIC",
            *if node.id
               [
                 " : ",
                 node.id,
               ]
             end,
          ].join
        end

        def format_data_types_integer(_node)
          "INTEGER"
        end

        def format_data_types_list(node)
          [
            "LIST",
            *if node.bound1 && node.bound2
               [
                 " ",
                 "[",
                 format(node.bound1),
                 ":",
                 format(node.bound2),
                 "]",
               ].join
             end,
            " ",
            "OF",
            *if node.unique
               [
                 " ",
                 "UNIQUE",
               ].join
             end,
            " ",
            format(node.base_type),
          ].join
        end

        def format_data_types_logical(_node)
          "LOGICAL"
        end

        def format_data_types_number(_node)
          "NUMBER"
        end

        def format_data_types_real(node)
          [
            "REAL",
            *if node.precision
               [
                 " ",
                 "(",
                 format(node.precision),
                 ")",
               ].join
             end,
          ].join
        end

        def format_data_types_select(node)
          indent_char = self.class.const_get(:INDENT_CHAR)
          items = Array(node.items)
          [
            *if node.extensible
               [
                 "EXTENSIBLE",
                 " ",
               ].join
             end,
            *if node.generic_entity
               [
                 "GENERIC_ENTITY",
                 " ",
               ].join
             end,
            "SELECT",
            *if node.based_on
               [
                 " ",
                 "BASED_ON",
                 " ",
                 format(node.based_on),
                 *if items.length.positive?
                    item_indent = indent_char * "(".length
                    [
                      " ",
                      "WITH",
                      "\n",
                      indent([
                        "(",
                        items.map do |x|
                          format(x)
                        end.join(",\n#{item_indent}"),
                        ")",
                      ].join),
                    ].join
                  end,
               ].join
             elsif items.length.positive?
               indent_char = self.class.const_get(:INDENT_CHAR)
               item_indent = indent_char * "(".length
               [
                 "\n",
                 indent([
                   "(",
                   items.map do |x|
                     format(x)
                   end.join(",\n#{item_indent}"),
                   ")",
                 ].join),
               ].join
             end,
          ].join
        end

        def format_data_types_set(node)
          [
            "SET",
            *if node.bound1 && node.bound2
               [
                 " ",
                 "[",
                 format(node.bound1),
                 ":",
                 format(node.bound2),
                 "]",
               ].join
             end,
            " ",
            "OF",
            " ",
            format(node.base_type),
          ].join
        end

        def format_data_types_string(node)
          [
            "STRING",
            *if node.width
               [
                 " ",
                 "(",
                 format(node.width),
                 ")",
               ].join
             end,
            *if node.fixed
               [
                 " ",
                 "FIXED",
               ].join
             end,
          ].join
        end
      end
    end
  end
end
