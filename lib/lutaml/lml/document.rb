# frozen_string_literal: true

require "lutaml/uml/document"
require "lutaml/lml/instance"
require "lutaml/lml/instance_collection"
require "lutaml/lml/document_require"

module Lutaml
  module Lml
    class Document < Lutaml::Uml::Document
      attribute :instance, Instance
      attribute :requires, DocumentRequire
      attribute :instances, InstanceCollection

      def requires
        return [] if @requires.empty?

        @requires.map(&:value)
      end
    end
  end
end
