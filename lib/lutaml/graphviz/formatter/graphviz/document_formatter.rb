# frozen_string_literal: true

module Lutaml
  module Formatter
    class Graphviz < Base
      module DocumentFormatter
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
          node.all_classes.map do |class_node|
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
          associations = sort_by_document_grouping(node.groups, associations) if node.groups
          classes_names = node.classes.map(&:name)
          format_filtered_associations(associations, classes_names, hide_other_classes)
        end

        def collect_all_associations(node)
          class_level = node.classifiable_classes
          Set.new
          all = class_level.filter_map(&:associations).flatten + node.associations
          all.uniq { |a| association_key(a) }
        end

        def format_filtered_associations(associations, classes_names, hide_other_classes)
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

        private

        def association_key(assoc)
          [assoc.owner_end.to_s, assoc.member_end.to_s, assoc.name.to_s]
        end
      end
    end
  end
end
