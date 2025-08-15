# frozen_string_literal: true

require "lutaml/uml/has_attributes"

module Lutaml
  module Uml
    module Node
      class Base
        include ::Lutaml::Uml::HasAttributes

        # rubocop:disable Rails/ActiveRecordAliases
        def initialize(attributes = {})
          update_attributes(attributes)
        end
        # rubocop:enable Rails/ActiveRecordAliases

        attr_accessor :parent
      end
    end
  end
end
