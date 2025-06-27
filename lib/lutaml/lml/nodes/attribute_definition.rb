module Lutaml
  module Lml
    module Nodes
      # Base class for all LML nodes
      class AttributeDefinition
        attr_accessor :name

        def initialize(name:, properties: [])
          @name = name
          @properties = properties
        end
      end
    end
  end
end
