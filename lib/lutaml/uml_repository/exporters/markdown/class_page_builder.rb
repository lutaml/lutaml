# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Exporters
      module Markdown
        class ClassPageBuilder
          include Formatting

          def initialize(repository, link_resolver)
            @repository = repository
            @link_resolver = link_resolver
          end

          def build(klass, qname)
            type = klass.class.name.split("::").last
            pkg_path = @link_resolver.extract_package_path(qname)

            <<~MARKDOWN
              # #{type}: #{klass.name}

              **Qualified Name**: `#{qname}`

              **Package**: [#{pkg_path}](#{@link_resolver.package_link(pkg_path)})

              #{build_stereotypes_section(klass)}

              #{build_definition_section(klass)}

              #{build_inheritance_section(klass)}

              #{build_attributes_section(klass)}

              #{build_operations_section(klass)}

              #{build_associations_section(klass)}

              #{build_enum_literals_section(klass)}

              ---

              [Back to Package](#{@link_resolver.package_link(pkg_path)}) | [Back to Index](../index.md)
            MARKDOWN
          end

          private

          def build_stereotypes_section(klass)
            stereotypes_array = normalize_stereotypes(klass.stereotype)
            return "" if stereotypes_array.empty?

            "**Stereotypes**: #{stereotypes_array.map { |s| "`#{s}`" }.join(', ')}\n\n"
          end

          def build_definition_section(klass)
            return "" unless klass.respond_to?(:definition) && klass.definition

            "## Description\n\n#{klass.definition}\n\n"
          end

          def build_inheritance_section(klass)
            parent = @repository.supertype_of(klass)
            children = @repository.subtypes_of(klass)

            return "" if parent.nil? && children.empty?

            content = "## Inheritance\n\n"

            if parent
              parent_qname = @link_resolver.qualified_name(parent)
              content += "**Extends**: [#{parent.name}](#{@link_resolver.class_link(parent_qname)})\n\n"
            end

            if children.any?
              content += "**Extended by**:\n\n"
              children.each do |child|
                child_qname = @link_resolver.qualified_name(child)
                content += "- [#{child.name}](#{@link_resolver.class_link(child_qname)})\n"
              end
              content += "\n"
            end

            content
          rescue StandardError
            ""
          end

          def build_attributes_section(klass)
            return "" unless klass.attributes&.any?

            content = "## Attributes\n\n"
            content += "| Name | Type | Visibility | Cardinality |\n"
            content += "|------|------|------------|-------------|\n"

            klass.attributes.each do |attr|
              visibility = attr.visibility || ""
              cardinality = format_cardinality(attr.cardinality)
              content += "| #{attr.name} | `#{attr.type}` | #{visibility} | " \
                         "#{cardinality} |\n"
            end

            "#{content}\n"
          end

          def build_operations_section(klass)
            return "" unless klass.respond_to?(:operations) && klass.operations&.any?

            content = "## Operations\n\n"
            content += "| Name | Return Type | Visibility |\n"
            content += "|------|-------------|------------|\n"

            klass.operations.each do |op|
              visibility = op.visibility || ""
              return_type = op.return_type || "void"
              content += "| #{op.name} | `#{return_type}` | #{visibility} |\n"
            end

            "#{content}\n"
          end

          def build_associations_section(klass)
            associations = @repository.associations_of(klass)
            return "" if associations.empty?

            content = "## Associations\n\n"
            content += "| Name | Target Class | Cardinality | Navigable |\n"
            content += "|------|--------------|-------------|-----------|\n"

            associations.each do |assoc|
              content += format_association_row(assoc, klass)
            end

            "#{content}\n"
          rescue StandardError
            ""
          end

          def format_association_row(association, klass)
            source_end = association.member_end&.first
            target_end = association.member_end&.last

            end_obj = if source_end&.type&.xmi_id == klass.xmi_id
                        target_end
                      else
                        source_end
                      end

            return "" unless end_obj&.type

            target_qname = @link_resolver.qualified_name(end_obj.type)
            name = association.name || end_obj.name || ""
            cardinality = format_cardinality(end_obj.cardinality)
            navigable = end_obj.navigable? ? "Yes" : "No"

            "| #{name} | [#{end_obj.type.name}](#{@link_resolver.class_link(target_qname)}) | " \
              "#{cardinality} | #{navigable} |\n"
          end

          def build_enum_literals_section(klass)
            unless klass.is_a?(Lutaml::Uml::Enum) && klass.owned_literal&.any?
              return ""
            end

            content = "## Literals\n\n"
            klass.owned_literal.each do |literal|
              content += "- `#{literal.name}`"
              content += ": #{literal.definition}" if literal.definition
              content += "\n"
            end

            "#{content}\n"
          end
        end
      end
    end
  end
end
