# frozen_string_literal: true

require "lutaml/uml/serializers/base"
require "lutaml/uml/serializers/class"

module Lutaml
  module Uml
    module Serializers
      class YamlView < Base
        property :name
        property :title
        property :caption
        property :groups
        property :fidelity
      end
    end
  end
end
