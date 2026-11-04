# lib/expressir/model.rb

module Expressir
  module Model
    # Marker modules — autoload the same concerns.rb file from each name.
    # The first reference triggers the load; the file defines all eight markers.
    autoload :HasId, "#{__dir__}/model/concerns"
    autoload :HasRemarkItems, "#{__dir__}/model/concerns"
    autoload :HasRemarks, "#{__dir__}/model/concerns"
    autoload :ScopeContainer, "#{__dir__}/model/concerns"
    autoload :HasInformalPropositions, "#{__dir__}/model/concerns"
    autoload :HasWhereRules, "#{__dir__}/model/concerns"
    autoload :TakesInlineRemark, "#{__dir__}/model/concerns"
    autoload :Statement, "#{__dir__}/model/concerns"

    autoload :ModelElement, "#{__dir__}/model/model_element"
    autoload :Cache, "#{__dir__}/model/cache"
    autoload :ExpFile, "#{__dir__}/model/exp_file"
    autoload :Identifier, "#{__dir__}/model/identifier"
    autoload :Repository, "#{__dir__}/model/repository"
    autoload :RepositoryValidator, "#{__dir__}/model/repository_validator"
    autoload :DependencyResolver, "#{__dir__}/model/dependency_resolver"
    autoload :RemarkFormat, "#{__dir__}/model/remark_format"
    autoload :RemarkPlacement, "#{__dir__}/model/remark_placement"
    autoload :RemarkInfo, "#{__dir__}/model/remark_info"
    autoload :InterfaceValidator, "#{__dir__}/model/interface_validator"
    autoload :SearchEngine, "#{__dir__}/model/search_engine"

    # Submodules - autoload their namespace files
    autoload :Indexes, "#{__dir__}/model/indexes"
    autoload :DataTypes, "#{__dir__}/model/data_types"
    autoload :Declarations, "#{__dir__}/model/declarations"
    autoload :Expressions, "#{__dir__}/model/expressions"
    autoload :Literals, "#{__dir__}/model/literals"
    autoload :References, "#{__dir__}/model/references"
    autoload :Statements, "#{__dir__}/model/statements"
    autoload :SupertypeExpressions, "#{__dir__}/model/supertype_expressions"
  end
end
