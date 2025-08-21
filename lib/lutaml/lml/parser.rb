# frozen_string_literal: true

require "lutaml/uml/parsers/dsl"

module Lutaml
  module Lml
    # Class for parsing LutaML lml into Lutaml::Lml::Document
    class Parser < Uml::Parsers::Dsl
      def create_uml_document(hash)
        Lutaml::Uml::Document.new(hash)
      end
    end
  end
end
