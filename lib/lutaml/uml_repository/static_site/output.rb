# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Output
        autoload :Strategy, "lutaml/uml_repository/static_site/output/strategy"
        autoload :VueInlinedStrategy,
                 "lutaml/uml_repository/static_site/output/vue_inlined_strategy"
        autoload :MultiFileStrategy,
                 "lutaml/uml_repository/static_site/output/multi_file_strategy"
      end
    end
  end
end
