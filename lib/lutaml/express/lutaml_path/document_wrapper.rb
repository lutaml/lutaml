require "lutaml/lutaml_path/document_wrapper"
require "expressir/express_exp/formatter"

module Lutaml
  module Express
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        SOURCE_CODE_ATTRIBUTE_NAME = "sourcecode".freeze

        protected

        def serialize_document(repository)
          repository.schemas.each_with_object({}) do |schema, res|
            res["schemas"] ||= []
            res[schema.id] = schema.to_hash(formatter: Expressir::ExpressExp::Formatter)
            res["schemas"].push(res[schema.id])
          end
        end
      end
    end
  end
end
