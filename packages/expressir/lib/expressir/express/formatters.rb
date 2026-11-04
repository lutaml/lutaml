module Expressir
  module Express
    # Formatter mixin modules
    module Formatters
      autoload :RemarkItemFormatter,
               "#{__dir__}/formatters/remark_item_formatter"
      autoload :RemarkFormatter, "#{__dir__}/formatters/remark_formatter"
      autoload :LiteralsFormatter, "#{__dir__}/formatters/literals_formatter"
      autoload :ReferencesFormatter,
               "#{__dir__}/formatters/references_formatter"
      autoload :SupertypeExpressionsFormatter,
               "#{__dir__}/formatters/supertype_expressions_formatter"
      autoload :StatementsFormatter,
               "#{__dir__}/formatters/statements_formatter"
      autoload :ExpressionsFormatter,
               "#{__dir__}/formatters/expressions_formatter"
      autoload :DataTypesFormatter, "#{__dir__}/formatters/data_types_formatter"
      autoload :DeclarationsFormatter,
               "#{__dir__}/formatters/declarations_formatter"
    end
  end
end
