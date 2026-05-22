# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        autoload :SpaBase, "lutaml/uml_repository/static_site/models/spa_base"
        autoload :SpaAssociation,
                 "lutaml/uml_repository/static_site/models/spa_association"
        autoload :SpaAssociationEnd,
                 "lutaml/uml_repository/static_site/models/spa_association_end"
        autoload :SpaAttribute,
                 "lutaml/uml_repository/static_site/models/spa_attribute"
        autoload :SpaCardinality,
                 "lutaml/uml_repository/static_site/models/spa_cardinality"
        autoload :SpaClass, "lutaml/uml_repository/static_site/models/spa_class"
        autoload :SpaDiagram,
                 "lutaml/uml_repository/static_site/models/spa_diagram"
        autoload :SpaDocument,
                 "lutaml/uml_repository/static_site/models/spa_document"
        autoload :SpaInheritedAssociation,
                 "lutaml/uml_repository/static_site/models/spa_inherited_association"
        autoload :SpaInheritedAttribute,
                 "lutaml/uml_repository/static_site/models/spa_inherited_attribute"
        autoload :SpaLiteral,
                 "lutaml/uml_repository/static_site/models/spa_literal"
        autoload :SpaMetadata,
                 "lutaml/uml_repository/static_site/models/spa_metadata"
        autoload :SpaOperation,
                 "lutaml/uml_repository/static_site/models/spa_operation"
        autoload :SpaPackage,
                 "lutaml/uml_repository/static_site/models/spa_package"
        autoload :SpaPackageTreeNode,
                 "lutaml/uml_repository/static_site/models/spa_package_tree_node"
        autoload :SpaParameter,
                 "lutaml/uml_repository/static_site/models/spa_parameter"
        autoload :SpaSearchEntry,
                 "lutaml/uml_repository/static_site/models/spa_search_entry"
        autoload :SpaSearchIndex,
                 "lutaml/uml_repository/static_site/models/spa_search_index"
        autoload :SpaStatistics,
                 "lutaml/uml_repository/static_site/models/spa_statistics"
        autoload :SpaTreeClassRef,
                 "lutaml/uml_repository/static_site/models/spa_tree_class_ref"
      end
    end
  end
end
