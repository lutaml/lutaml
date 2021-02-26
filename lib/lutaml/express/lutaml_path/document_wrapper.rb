require "lutaml/lutaml_path/document_wrapper"
require "expressir/express_exp/hyperlink_formatter"

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        protected

        def serialize_document(repository)
          repository
            .to_hash(formatter: Expressir::ExpressExp::HyperlinkFormatter)['schemas']
        end
      end
    end
  end
end
