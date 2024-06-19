# frozen_string_literal: true

module Lutaml
  module Uml
    module HasAttributes
      def update_attributes(attributes = {})
        attributes.to_h.each do |name, value|
          value = value.respond_to?(:str) ? value.str : value
          public_send("#{name}=", value)
        end
      end
    end
  end
end
