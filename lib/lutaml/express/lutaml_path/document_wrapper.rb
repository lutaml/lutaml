require "lutaml/lutaml_path/document_wrapper"
require "lutaml/express/lutaml_path/formatter"

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        protected

        def serialize_document(repository)
          repository
            .to_hash(formatter: Formatter)
        end
      end
    end
  end
end
