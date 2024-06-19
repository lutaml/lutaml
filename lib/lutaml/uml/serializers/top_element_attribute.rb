# frozen_string_literal: true

require "lutaml/uml/serializers/base"

module Lutaml
  module Uml
    module Serializers
      class TopElementAttribute < Base
        property :cardinality
        property :type
      end
    end
  end
end
