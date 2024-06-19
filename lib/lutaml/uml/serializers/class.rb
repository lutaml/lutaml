# frozen_string_literal: true

require "lutaml/uml/serializers/base"
require "lutaml/uml/serializers/top_element_attribute"
require "lutaml/uml/serializers/association"

module Lutaml
  module Uml
    module Serializers
      class Class < Base
        property :attributes,
                 transform_with: (lambda do |entry|
                   entry
                    .to_a
                    .map do |(name, attributes)|
                      attributes.merge(name: name)
                    end
                 end)
        property :associations,
                 from: :relations,
                 coerce: Array[::Lutaml::Uml::Serializers::Association]
        property :name
        # property :type, from: :modelType
        # property :relations,
        #          coerce: Array[Relation]
      end
    end
  end
end
