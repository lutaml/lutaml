# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        autoload :AssociationSerializer,
                 "lutaml/uml_repository/static_site/serializers/association_serializer"
        autoload :AttributeSerializer,
                 "lutaml/uml_repository/static_site/serializers/attribute_serializer"
        autoload :Base,
                 "lutaml/uml_repository/static_site/serializers/base"
        autoload :ClassSerializer,
                 "lutaml/uml_repository/static_site/serializers/class_serializer"
        autoload :DiagramSerializer,
                 "lutaml/uml_repository/static_site/serializers/diagram_serializer"
        autoload :InheritanceResolver,
                 "lutaml/uml_repository/static_site/serializers/inheritance_resolver"
        autoload :MetadataBuilder,
                 "lutaml/uml_repository/static_site/serializers/metadata_builder"
        autoload :OperationSerializer,
                 "lutaml/uml_repository/static_site/serializers/operation_serializer"
        autoload :PackageSerializer,
                 "lutaml/uml_repository/static_site/serializers/package_serializer"
        autoload :PackageTreeBuilder,
                 "lutaml/uml_repository/static_site/serializers/package_tree_builder"
      end
    end
  end
end
