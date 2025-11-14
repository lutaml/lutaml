# frozen_string_literal: true

require_relative "relationship"
require_relative "has_name"

module Lutaml
  module Uml
    module Node
      class ClassRelationship < Relationship
        include HasName
      end
    end
  end
end
