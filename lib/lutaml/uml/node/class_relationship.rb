# frozen_string_literal: true

require "lutaml/uml/node/relationship"
require "lutaml/uml/node/has_name"

module Lutaml
  module Uml
    module Node
      class ClassRelationship < Relationship
        include HasName
      end
    end
  end
end
