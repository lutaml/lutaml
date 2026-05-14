# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Exporters
      module Markdown
        autoload :LinkResolver,
                 "lutaml/uml_repository/exporters/markdown/link_resolver"
        autoload :Formatting,
                 "lutaml/uml_repository/exporters/markdown/formatting"
        autoload :IndexPageBuilder,
                 "lutaml/uml_repository/exporters/markdown/index_page_builder"
        autoload :PackagePageBuilder,
                 "lutaml/uml_repository/exporters/markdown/package_page_builder"
        autoload :ClassPageBuilder,
                 "lutaml/uml_repository/exporters/markdown/class_page_builder"
      end
    end
  end
end
