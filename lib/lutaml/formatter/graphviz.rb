# frozen_string_literal: true

require "open3"

module Lutaml
  module Formatter
    class Graphviz < Base
      class Attributes < Hash
        def to_s
          to_a
            .reject { |(_k, val)| val.nil? }
            .map { |(a, b)| "#{a}=#{b.inspect}" }
            .join(" ")
        end
      end

      ACCESS_SYMBOLS = {
        "public" => "+",
        "protected" => "#",
        "private" => "-",
      }.freeze
      DEFAULT_CLASS_FONT = "Helvetica"

      VALID_TYPES = %i[
        dot
        xdot
        ps
        pdf
        svg
        svgz
        fig
        png
        gif
        jpg
        jpeg
        json
        imap
        cmapx
      ].freeze

      def initialize(attributes = {}) # rubocop:disable Metrics/MethodLength
        super

        @graph = Attributes.new
        # Associations lines style, `true` gives curved lines
        # https://graphviz.org/doc/info/attrs.html#d:splines
        @graph["splines"] = "ortho"
        # Padding between outside of picture and nodes
        @graph["pad"] = 0.5
        # Padding between levels
        @graph["ranksep"] = "1.2.equally"
        # Padding between nodes
        @graph["nodesep"] = "1.2.equally"
        @graph["rankdir"] = "BT"

        @edge = Attributes.new
        @edge["color"] = "gray50"

        @node = Attributes.new
        @node["shape"] = "box"

        @type = :dot
      end

      attr_reader :graph, :edge, :node

      def type=(value)
        super

        @type = :dot unless VALID_TYPES.include?(@type)
      end

      def format(node)
        dot = super.lines.map(&:rstrip).join("\n")

        generate_from_dot(dot)
      end

      def escape_html_chars(text)
        text
          .gsub("<", "&#60;")
          .gsub(">", "&#62;")
          .gsub("[", "&#91;")
          .gsub("]", "&#93;")
      end

      def format_attribute(node) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        symbol = ACCESS_SYMBOLS[node.visibility]
        result = "#{symbol}#{node.name}"
        if node.type
          keyword = node.keyword ? "«#{node.keyword}»" : ""
          result += " : #{keyword}#{node.type}"
        end
        if node.cardinality
          result += "[#{node.cardinality.min}.." \
                    "#{node.cardinality.max}]"
        end
        result = escape_html_chars(result)
        result = "<U>#{result}</U>" if node.static

        result
      end

      def format_operation(node) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        symbol = ACCESS_SYMBOLS[node.access]
        result = "#{symbol} #{node.name}"
        if node.arguments
          arguments = node.arguments.map do |argument|
            "#{argument.name}#{" : #{argument.type}" if argument.type}"
          end.join(", ")
        end

        result << "(#{arguments})"
        result << " : #{node.type}" if node.type
        result = "<U>#{result}</U>" if node.static
        result = "<I>#{result}</I>" if node.abstract

        result
      end

      def format_relationship(node)
        graph_parent_name = generate_graph_name(node.owner_end)
        graph_node_name = generate_graph_name(node.member_end)
        attributes = generate_graph_relationship_attributes(node)
        graph_attributes = " [#{attributes}]" unless attributes.empty?

        %{#{graph_parent_name} -> #{graph_node_name}#{graph_attributes}}
      end

      def generate_graph_relationship_attributes(node) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        attributes = Attributes.new
        if %w[dependency realizes].include?(node.member_end_type)
          attributes["style"] = "dashed"
        end
        attributes["dir"] = if node.owner_end_type && node.member_end_type
                              "both"
                            elsif node.owner_end_type
                              "back"
                            else
                              "direct"
                            end

        if node&.action&.verb
          attributes["label"] = node.action.verb
        end
        case node&.action&.direction
        when "target"
          attributes["label"] = "#{attributes['label']} \u25b6"
        when "source"
          attributes["label"] = "\u25c0 #{attributes['label']}"
        end

        if node.owner_end_attribute_name
          attributes["headlabel"] = format_label(
            node.owner_end_attribute_name,
            node.owner_end_cardinality,
          )
        end
        if node.member_end_attribute_name
          attributes["taillabel"] = format_label(
            node.member_end_attribute_name,
            node.member_end_cardinality,
          )
        end

        attributes["arrowtail"] = case node.owner_end_type
                                  when "composition"
                                    "diamond"
                                  when "aggregation"
                                    "odiamond"
                                  when "direct"
                                    "vee"
                                  else
                                    "onormal"
                                  end

        attributes["arrowhead"] = case node.member_end_type
                                  when "composition"
                                    "diamond"
                                  when "aggregation"
                                    "odiamond"
                                  when "direct"
                                    "vee"
                                  else
                                    "onormal"
                                  end
        # swap labels and arrows if `dir` eq to `back`
        if attributes["dir"] == "back" && attributes["arrowtail"] != "vee"
          attributes["arrowhead"], attributes["arrowtail"] =
            [attributes["arrowtail"], attributes["arrowhead"]]
          attributes["headlabel"], attributes["taillabel"] =
            [attributes["taillabel"], attributes["headlabel"]]
        end
        attributes
      end

      def format_label(name, cardinality = {})
        res = "+#{name}"
        if cardinality.nil? ||
            (cardinality.min.nil? || cardinality.max.nil?)
          return res
        end

        "#{res} #{cardinality.min}..#{cardinality.max}"
      end

      EMPTY_MEMBER_TABLE = <<~HEREDOC.chomp
        <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
          <TR><TD ALIGN="LEFT"></TD></TR>
        </TABLE>
      HEREDOC

      def format_member_rows(members, hide_members)
        return EMPTY_MEMBER_TABLE if hide_members || !members&.any?

        field_rows = members.map do |field|
          %{<TR><TD ALIGN="LEFT">#{format_attribute(field)}</TD></TR>}
        end
        build_member_table(field_rows)
      end

      def build_member_table(field_rows)
        <<~HEREDOC.chomp
          <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
            #{field_rows.map { |row| (' ' * 10) + row }.join("\n")}
          </TABLE>
        HEREDOC
          .concat("\n")
          .concat(" " * 6)
      end

      def format_class(node, hide_members) # rubocop:disable Metrics/MethodLength
        name = ["<B>#{node.name}</B>"]
        name.unshift("«#{node.keyword}»") if node.keyword
        name_html = build_name_table(name)

        field_table = format_member_rows(node.attributes, hide_members)
        method_table = if node.operations&.any?
                         format_member_rows(node.operations, hide_members)
                       end
        table_body = build_table_body(name_html, field_table, method_table)

        <<~HEREDOC.chomp
          <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10">
            #{table_body}
          </TABLE>
        HEREDOC
      end

      def build_name_table(name_parts)
        <<~HEREDOC
          <TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
            #{name_parts.map { |n| %(<TR><TD ALIGN="CENTER">#{n}</TD></TR>) }.join('\n')}
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

      def format_document(node)
        @fontname = node.fontname || DEFAULT_CLASS_FONT
        @node["fontname"] = "#{@fontname}-bold"

        hide_members, hide_other_classes = extract_fidelity_options(node)
        classes = format_all_classes(node, hide_members)
        associations = build_associations(node, hide_other_classes)

        build_digraph(classes, associations)
      end

      def extract_fidelity_options(node)
        if node.fidelity
          [node.fidelity.hideMembers, node.fidelity.hideOtherClasses]
        else
          [nil, nil]
        end
      end

      def format_all_classes(node, hide_members)
        all_classes = node.classes + node.enums + node.data_types + node.primitives
        all_classes.map do |class_node|
          graph_node_name = generate_graph_name(class_node.name)
          <<~HEREDOC
            #{graph_node_name} [
              shape="plain"
              fontname="#{@fontname || DEFAULT_CLASS_FONT}"
              label=<#{format_class(class_node, hide_members)}>]
          HEREDOC
        end.join("\n")
      end

      def build_associations(node, hide_other_classes)
        associations = collect_all_associations(node)
        if node.groups
          associations = sort_by_document_grouping(node.groups,
                                                   associations)
        end

        classes_names = node.classes.map(&:name)
        format_filtered_associations(associations, classes_names,
                                     hide_other_classes)
      end

      def collect_all_associations(node)
        node.classes.filter_map(&:associations).flatten + node.associations
      end

      def format_filtered_associations(associations, classes_names,
hide_other_classes)
        associations.filter_map do |assoc_node|
          next if hide_other_classes && !classes_names.include?(assoc_node.member_end)

          format_relationship(assoc_node)
        end.join("\n")
      end

      def build_digraph(classes, associations)
        indented_classes = indent_lines(classes)
        indented_assocs = indent_lines(associations)

        <<~HEREDOC
          digraph G {
            graph [#{@graph}]
            edge [#{@edge}]
            node [#{@node}]

          #{indented_classes}

          #{indented_assocs}
          }
        HEREDOC
      end

      def indent_lines(text)
        text.lines.map { |line| "  #{line}" }.join.chomp
      end

      protected

      def sort_by_document_grouping(groups, associations) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        result = []
        groups.each do |group|
          group.values.each do |group_name| # rubocop:disable Style/HashEachMethods
            associations
              .select { |assc| assc.owner_end == group_name }
              .each do |association|
                result.push(association) unless result.include?(association)
              end
          end
        end
        associations.each do |association|
          result.push(association) unless result.include?(association)
        end
        result
      end

      def generate_from_dot(input)
        Lutaml::Layout::GraphVizEngine.new(input: input).render(@type)
      end

      def generate_graph_name(name)
        name.gsub(/[^0-9a-zA-Z]/i, "")
      end
    end
  end
end
