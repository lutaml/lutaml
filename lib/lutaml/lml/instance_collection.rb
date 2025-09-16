# frozen_string_literal: true

require 'lutaml/lml/instance'
require 'lutaml/lml/instances_import'
require 'lutaml/lml/instances_export'
require 'lutaml/lml/collection'

module Lutaml
  module Lml
    class InstanceCollection < Lutaml::Model::Serializable
      attribute :instances, Instance, collection: true, default: []
      attribute :imports, InstancesImport, collection: true, default: []
      attribute :exports, InstancesExport, collection: true, default: []
      attribute :collections, Collection, default: []
    end
  end
end