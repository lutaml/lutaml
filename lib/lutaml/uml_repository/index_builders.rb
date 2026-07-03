# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module IndexBuilders
      autoload :PackageIndex,
               "lutaml/uml_repository/index_builders/package_index"
      autoload :ClassIndex, "lutaml/uml_repository/index_builders/class_index"
      autoload :AssociationIndex,
               "lutaml/uml_repository/index_builders/association_index"
    end
  end
end
