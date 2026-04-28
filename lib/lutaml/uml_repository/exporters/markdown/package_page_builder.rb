# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Exporters
      module Markdown
        class PackagePageBuilder
          include Formatting

          def initialize(repository, link_resolver)
            @repository = repository
            @link_resolver = link_resolver
          end

          def build(package, path)
            classes = @repository.classes_in_package(path, recursive: false)
            sub_packages = package.packages || []

            <<~MARKDOWN
              # Package: #{package.name}

              **Qualified Path**: `#{path}`

              ## Description

              #{package.definition || 'No description available.'}

              ## Statistics

              - **Direct Classes**: #{classes.size}
              - **Sub-packages**: #{sub_packages.size}

              #{build_sub_packages_section(sub_packages)}

              #{build_classes_section(classes)}

              #{build_diagrams_section(path)}

              ---

              [Back to Index](../index.md)
            MARKDOWN
          end

          private

          def build_sub_packages_section(packages)
            return "" if packages.empty?

            content = "## Sub-packages\n\n"
            packages.each do |pkg|
              pkg_path = @link_resolver.package_path(pkg)
              link = @link_resolver.package_link(pkg_path)
              content += "- [#{pkg.name}](#{link})\n"
            end
            "#{content}\n"
          end

          def build_classes_section(classes)
            return "## Classes\n\nNo classes in this package.\n" if classes.empty?

            content = "## Classes\n\n"
            content += "| Name | Type | Stereotypes | Attributes | Associations |\n"
            content += "|------|------|-------------|------------|--------------|\n"

            classes.sort_by(&:name).each do |klass|
              content += format_class_table_row(klass)
            end

            "#{content}\n"
          end

          def format_class_table_row(klass)
            qname = @link_resolver.qualified_name(klass)
            link = @link_resolver.class_link(qname)
            type = klass.class.name.split("::").last
            stereotypes = format_stereotypes(klass.stereotype)
            attrs_count = klass.attributes&.size || 0
            assocs_count = count_associations(klass)

            "| [#{klass.name}](#{link}) | #{type} | #{stereotypes} | " \
              "#{attrs_count} | #{assocs_count} |\n"
          end

          def build_diagrams_section(package_path)
            diagrams = @repository.diagrams_in_package(package_path)
            return "" if diagrams.empty?

            content = "## Diagrams\n\n"
            diagrams.each do |diagram|
              content += "- **#{diagram.name}** (#{diagram.diagram_type})\n"
            end
            "#{content}\n"
          rescue StandardError
            ""
          end

          def count_associations(klass)
            @repository.associations_of(klass).size
          rescue StandardError
            0
          end
        end
      end
    end
  end
end
