# frozen_string_literal: true

module Expressir
  module Model
    module Statements
      autoload :Alias, "#{__dir__}/statements/alias"
      autoload :Assignment, "#{__dir__}/statements/assignment"
      autoload :Case, "#{__dir__}/statements/case"
      autoload :CaseAction, "#{__dir__}/statements/case_action"
      autoload :Compound, "#{__dir__}/statements/compound"
      autoload :Escape, "#{__dir__}/statements/escape"
      autoload :If, "#{__dir__}/statements/if"
      autoload :Null, "#{__dir__}/statements/null"
      autoload :ProcedureCall, "#{__dir__}/statements/procedure_call"
      autoload :Repeat, "#{__dir__}/statements/repeat"
      autoload :Return, "#{__dir__}/statements/return"
      autoload :Skip, "#{__dir__}/statements/skip"
    end
  end
end
