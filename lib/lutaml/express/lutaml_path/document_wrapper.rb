require "lutaml/lutaml_path/document_wrapper"
require "lutaml/express/lutaml_path/formatter"

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        attr_accessor :select_proc

        protected

        def serialize_document(repository)
          repository.to_hash(
            formatter: Formatter,
            include_empty: true,
            select_proc: select_proc
          )
        end
      end
    end
  end
end
