# frozen_string_literal: true

module Expressir
  # ISO 10303-21 exchange-structure support (TODO.eengine/06).
  module P21
    autoload :Population, "#{__dir__}/p21/population"
    autoload :Record, "#{__dir__}/p21/population"
    autoload :ComplexRecord, "#{__dir__}/p21/population"
    autoload :TypedValue, "#{__dir__}/p21/population"
    autoload :Enumeration, "#{__dir__}/p21/population"
    autoload :Binary, "#{__dir__}/p21/population"
    autoload :Grammar, "#{__dir__}/p21/grammar"
    autoload :Builder, "#{__dir__}/p21/builder"
    autoload :Validator, "#{__dir__}/p21/validator"
    autoload :Typing, "#{__dir__}/p21/typing"
    autoload :DatasetManifest, "#{__dir__}/p21/dataset_manifest"
    autoload :Receipt, "#{__dir__}/p21/receipt"
    autoload :Diff, "#{__dir__}/p21/diff"
    autoload :Parser, "#{__dir__}/p21/parser"
    autoload :Writer, "#{__dir__}/p21/writer"
    autoload :Json, "#{__dir__}/p21/json"
  end
end
