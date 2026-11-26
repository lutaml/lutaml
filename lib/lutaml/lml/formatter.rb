# frozen_string_literal: true

module Lutaml
  # Output formatters: diagram renderers and the canonical LML emitter.
  module Formatter
    autoload :Base, "lutaml/lml/formatter/base"
    autoload :Elk, "lutaml/lml/formatter/elk"
    autoload :SvgPdf, "lutaml/lml/formatter/svg_pdf"
    autoload :Canonical, "lutaml/lml/formatter/canonical"
  end
end
