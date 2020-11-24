require "lutaml/lutaml_path/document_wrapper"

module Lutaml
  module Uml
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        protected

        def serialize_document(document)
          serialize_to_hash(document)
        end
      end
    end
  end
end
