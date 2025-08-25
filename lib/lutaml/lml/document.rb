# frozen_string_literal: true

require "lutaml/uml/document"
require "lutaml/lml/instance"
require "lutaml/lml/instance_collection"

module Lutaml
  module Lml
    class Document < Lutaml::Uml::Document
      attribute :instance, Instance
      attribute :requires, :string, collection: true
      attribute :instances, InstanceCollection
    end
  end
end
