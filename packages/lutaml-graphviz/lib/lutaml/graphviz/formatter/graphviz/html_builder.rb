# frozen_string_literal: true

module Lutaml
  module Formatter
    class Graphviz < Base
      module HtmlBuilder
        EMPTY_MEMBER_TABLE = <<~HEREDOC.chomp
          <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
            <TR><TD ALIGN="LEFT"></TD></TR>
          </TABLE>
        HEREDOC

        def escape_html_chars(text)
          text
            .gsub("&", "&amp;")
            .gsub("<", "&#60;")
            .gsub(">", "&#62;")
            .gsub("[", "&#91;")
            .gsub("]", "&#93;")
        end

        def format_member_rows(members, hide_members, &formatter)
          return EMPTY_MEMBER_TABLE if hide_members || !members&.any?

          formatter ||= method(:dispatch_format)
          field_rows = members.map do |member|
            %(<TR><TD ALIGN="LEFT">#{formatter.call(member)}</TD></TR>)
          end
          build_member_table(field_rows)
        end

        def format_enum_member(member)
          enum_literal?(member) ? format_enum_literal(member) : dispatch_format(member)
        end

        def enum_literal?(node)
          node.is_a?(Lml::TopElementAttribute) &&
            node.type.nil? && node.cardinality.nil?
        end

        def build_member_table(field_rows)
          indented = field_rows.map { |row| (" " * 10) + row }.join("\n")
          <<~HEREDOC.chomp
            <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
              #{indented}
            </TABLE>
          HEREDOC
                    .concat("\n")
                    .concat(" " * 6)
        end

        def build_name_table(name_parts)
          <<~HEREDOC
            <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
              #{name_parts.map { |n| %(<TR><TD ALIGN="CENTER">#{n}</TD></TR>) }.join("\n")}
            </TABLE>
          HEREDOC
        end

        def build_table_body(name_html, field_table, method_table)
          [name_html, field_table, method_table].compact.filter_map do |type|
            <<~TEXT
              <TR>
                <TD>#{type}</TD>
              </TR>
            TEXT
          end.join("\n")
        end
      end
    end
  end
end
