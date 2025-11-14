# frozen_string_literal: true

require "liquid"
require "lutaml/path"

module Lutaml
  module UmlRepository
    # Core utilities
    autoload :Configuration, "lutaml/uml_repository/configuration"
    autoload :ErrorHandler, "lutaml/uml_repository/error_handler"
    autoload :SearchResult, "lutaml/uml_repository/search_result"

    # Main repository classes
    autoload :Repository, "lutaml/uml_repository/repository"
    autoload :LazyRepository, "lutaml/uml_repository/lazy_repository"
    autoload :RepositoryEnhanced, "lutaml/uml_repository/repository_enhanced"
    autoload :DocGenerator, "lutaml/uml_repository/doc_generator"
    autoload :StaticSite, "lutaml/uml_repository/static_site"

    # Exporters
    module Exporters
      autoload :BaseExporter, "lutaml/uml_repository/exporters/base_exporter"
      autoload :CsvExporter, "lutaml/uml_repository/exporters/csv_exporter"
      autoload :JsonExporter, "lutaml/uml_repository/exporters/json_exporter"
      autoload :MarkdownExporter,
               "lutaml/uml_repository/exporters/markdown_exporter"
    end

    # Query DSL
    module QueryDsl
      autoload :QueryBuilder, "lutaml/uml_repository/query_dsl/query_builder"
      autoload :Order, "lutaml/uml_repository/query_dsl/order"
    end

    # Presenters
    module Presenters
      autoload :ElementPresenter,
               "lutaml/uml_repository/presenters/element_presenter"
      autoload :PresenterFactory,
               "lutaml/uml_repository/presenters/presenter_factory"
      autoload :ClassPresenter,
               "lutaml/uml_repository/presenters/class_presenter"
      autoload :AttributePresenter,
               "lutaml/uml_repository/presenters/attribute_presenter"
      autoload :AssociationPresenter,
               "lutaml/uml_repository/presenters/association_presenter"
      autoload :EnumPresenter, "lutaml/uml_repository/presenters/enum_presenter"
      autoload :DatatypePresenter,
               "lutaml/uml_repository/presenters/datatype_presenter"
    end

    # Repository components (loaded on demand by UmlRepository)
    module UmlRepositoryComponents
      autoload :IndexBuilder, "lutaml/uml_repository/index_builder"
      autoload :StatisticsCalculator,
               "lutaml/uml_repository/statistics_calculator"
      autoload :PackageExporter, "lutaml/uml_repository/package_exporter"
      autoload :PackageLoader, "lutaml/uml_repository/package_loader"
    end

    # Query classes
    module Queries
      autoload :BaseQuery, "lutaml/uml_repository/queries/base_query"
      autoload :PackageQuery, "lutaml/uml_repository/queries/package_query"
      autoload :ClassQuery, "lutaml/uml_repository/queries/class_query"
      autoload :InheritanceQuery,
               "lutaml/uml_repository/queries/inheritance_query"
      autoload :AssociationQuery,
               "lutaml/uml_repository/queries/association_query"
      autoload :DiagramQuery, "lutaml/uml_repository/queries/diagram_query"
      autoload :SearchQuery, "lutaml/uml_repository/queries/search_query"
    end

    # Validators
    module Validators
      autoload :RepositoryValidator,
               "lutaml/uml_repository/validators/repository_validator"
    end

    # Web UI
    module WebUi
      autoload :App, "lutaml/uml_repository/web_ui/app"
    end

    # Static Site Generator
    module StaticSiteComponents
      autoload :Configuration, "lutaml/uml_repository/static_site/configuration"
      autoload :IdGenerator, "lutaml/uml_repository/static_site/id_generator"
      autoload :DataTransformer,
               "lutaml/uml_repository/static_site/data_transformer"
      autoload :SearchIndexBuilder,
               "lutaml/uml_repository/static_site/search_index_builder"
      autoload :Generator, "lutaml/uml_repository/static_site/generator"
    end
  end
end
