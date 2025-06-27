# frozen_string_literal: true

require_relative "model"

module Lutaml
  module Lml
    module Nodes
      class Document
        attr_accessor :model

        def initialize(model: nil)
          @model = model
        end
      end
    end
  end
end
