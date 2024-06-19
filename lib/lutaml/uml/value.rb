# frozen_string_literal: true

module Lutaml
  module Uml
    class Value
      include HasAttributes
      include HasMembers

      attr_accessor :definition,
                    :name,
                    :id,
                    :type

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
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
