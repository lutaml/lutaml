require "expressir/express_exp/formatter"
require "expressir/express_exp/schema_head_formatter"
require "expressir/express_exp/hyperlink_formatter"

module Lutaml
  module Express
    module LutamlPath
      class Formatter < Expressir::ExpressExp::Formatter
        include Expressir::ExpressExp::SchemaHeadFormatter
        include Expressir::ExpressExp::HyperlinkFormatter
      end
    end
  end
end