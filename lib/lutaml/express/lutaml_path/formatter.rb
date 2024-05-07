require "expressir/express/formatter"
require "expressir/express/schema_head_formatter"
require "expressir/express/hyperlink_formatter"

module Lutaml
  module Express
    module LutamlPath
      class Formatter < Expressir::Express::Formatter
        include Expressir::Express::SchemaHeadFormatter
        include Expressir::Express::HyperlinkFormatter
      end
    end
  end
end
