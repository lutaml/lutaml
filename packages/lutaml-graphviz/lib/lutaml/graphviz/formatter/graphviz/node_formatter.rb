# frozen_string_literal: true

module Lutaml
  module Formatter
    class Graphviz < Base
      module NodeFormatter
        ACCESS_SYMBOLS = {
          "public" => "+",
          "protected" => "#",
          "private" => "-",
          "package" => "~"
        }.freeze

        def format_attribute(node)
          symbol = ACCESS_SYMBOLS[node.visibility]
          result = "#{symbol}#{node.name}"
          if node.type
            stereotype = node.stereotype.empty? ? "" : node.stereotype.map { |s| "«#{s}»" }.join
            result += " : #{stereotype}#{node.type}"
          end
          result += format_cardinality_bounds(node.cardinality) if node.cardinality
          result = escape_html_chars(result)
          result = "<U>#{result}</U>" if node.static
          result
        end

        def format_cardinality_bounds(cardinality)
          min = cardinality.min || "*"
          max = cardinality.max || "*"
          "[#{min}..#{max}]"
        end

        def format_operation(node)
          symbol = ACCESS_SYMBOLS[node.visibility]
          params = format_operation_params(node.owned_parameter)
          result = "#{symbol} #{node.name}(#{params})"
          result << " : #{node.return_type}" if node.return_type
          result = escape_html_chars(result)
          result = "<U>#{result}</U>" if node.is_static
          result = "<I>#{result}</I>" if node.is_abstract
          result
        end

        def format_operation_params(params)
          return "" unless params&.any?

          params.map do |param|
            param.type ? "#{param.name} : #{param.type}" : param.name.to_s
          end.join(", ")
        end

        # Kind labels rendered above the name: guillemet stereotypes first,
        # then the entity-kind label (enums/data types/primitives carry no
        # user stereotypes of their own in the grammar).
        KIND_LABELS = {
          enums: "enumeration",
          data_types: "dataType",
          primitives: "primitive"
        }.freeze

        def format_class(node, hide_members = nil)
          name = ["<B>#{escape_html_chars(node.name)}</B>"]
          node.stereotype.each do |stereotype|
            name.unshift("«#{escape_html_chars(stereotype)}»")
          end
          if (kind = KIND_LABELS[node.class.entity_type])
            name.unshift("«#{kind}»")
          end
          name_html = build_name_table(name)

          member_formatter = node.is_a?(Lml::Enum) ? method(:format_enum_member) : nil
          field_table = format_member_rows(node.attributes, hide_members, &member_formatter)
          method_table = format_member_rows(node.operations, hide_members) if node.operations&.any?
          table_body = build_table_body(name_html, field_table, method_table)

          <<~HEREDOC.chomp
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10">
              #{table_body}
            </TABLE>
          HEREDOC
        end

        def format_enum_literal(node)
          "<I>#{escape_html_chars(node.name.to_s)}</I>"
        end
      end
    end
  end
end
