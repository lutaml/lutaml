# frozen_string_literal: true

module Expressir
  module Express
    # EXPRESS grammar namespace. Houses the Parsanol grammar definition
    # separate from the I/O orchestration on the outer Parser facade.
    module Grammar
      autoload :Parser, "#{__dir__}/grammar/parser"
    end
  end
end
