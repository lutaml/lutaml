# frozen_string_literal: true

module Expressir
  module Model
    module Indexes
      autoload :EntityIndex, "#{__dir__}/indexes/entity_index"
      autoload :TypeIndex, "#{__dir__}/indexes/type_index"
      autoload :ReferenceIndex, "#{__dir__}/indexes/reference_index"
      autoload :ItemGraph, "#{__dir__}/indexes/item_graph"
    end
  end
end
