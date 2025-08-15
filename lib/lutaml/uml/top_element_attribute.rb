# frozen_string_literal: true

module Lutaml
  module Uml
    class TopElementAttribute
      include HasAttributes
      include HasMembers

      attr_reader :definition
      attr_accessor :name,
                    :visibility,
                    :type,
                    :id,
                    :xmi_id,
                    :contain,
                    :static,
                    :cardinality,
                    :keyword,
                    :is_derived,
                    :properties

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        @visibility = "public"
        @properties = {}
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases

      def properties=(values)
        values.each do |value|
          property, property_value = value.values_at(:name, :value)
          next public_send(:"#{property}=", property_value) if respond_to?("#{property}=")

          properties[property] = property_value
        end
      end

      def definition=(value)
        @definition = value
          .to_s
          .gsub(/\\}/, "}")
          .gsub(/\\{/, "{")
          .split("\n")
          .map(&:strip)
          .join("\n")
      end
    end
  end
end
