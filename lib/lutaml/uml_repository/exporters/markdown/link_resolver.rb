# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Exporters
      module Markdown
        class LinkResolver
          def initialize(indexes)
            @indexes = indexes
          end

          def package_link(path)
            "../packages/#{sanitize_filename(path)}.md"
          end

          def class_link(qname)
            "../classes/#{sanitize_filename(qname)}.md"
          end

          def package_path(package)
            @indexes&.dig(:package_to_path, package.xmi_id) || package.name
          end

          def qualified_name(klass)
            @indexes&.dig(:class_to_qname, klass.xmi_id) || klass.name
          end

          def extract_package_path(qname)
            parts = qname.split("::")
            parts.size > 1 ? parts[0..-2].join("::") : "ModelRoot"
          end

          def sanitize_filename(name)
            name.gsub("::", "_").gsub(/[^a-zA-Z0-9_\-.]/, "_")
          end
        end
      end
    end
  end
end
