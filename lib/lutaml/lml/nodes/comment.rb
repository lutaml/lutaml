# frozen_string_literal: true

module Lutaml
  module Lml
    module Nodes
      class Comment
        attr_accessor :text

        def initialize(text:)
          @text = text
        end
      end
    end
  end
end
