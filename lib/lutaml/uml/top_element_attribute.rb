# frozen_string_literal: true

module Lutaml
  module Uml
    class TopElementAttribute
      include HasAttributes
      include HasMembers

      attr_accessor :name,
                    :visibility,
                    :type,
                    :id,
                    :xmi_id,
                    :definition,
                    :contain,
                    :static,
                    :cardinality,
                    :keyword,
                    :is_derived

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        @visibility = "public"
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases

      def definition=(value)
        @definition = value
                        .to_s
                        .gsub(/\\}/, '}')
                        .gsub(/\\{/, '{')
                        .split("\n")
                        .map(&:strip)
                        .join("\n")
      end
    end
  end
end
