# frozen_string_literal: true

module Expressir
  # The EXPRESS evaluator (TODO.sota/02): runs the language's
  # expressions, functions and rules over values and — from step 3 —
  # Part 21 populations. The evaluator consumes the same model the
  # parser produces; nothing here re-parses.
  module Eval
    class Error < StandardError; end

    autoload :Values, "#{__dir__}/eval/values"
    autoload :Environment, "#{__dir__}/eval/environment"
    autoload :Expression, "#{__dir__}/eval/expression"
    autoload :Interpreter, "#{__dir__}/eval/interpreter"
    autoload :Rules, "#{__dir__}/eval/rules"
    autoload :Population, "#{__dir__}/eval/population"
    autoload :BuiltinMatrix, "#{__dir__}/eval/builtin_matrix"
  end
end
