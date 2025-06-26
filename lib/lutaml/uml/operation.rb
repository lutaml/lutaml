# frozen_string_literal: true

module Lutaml
  module Uml
    class Operation
      include HasAttributes
      include HasMembers

      attr_reader :definition
      attr_accessor :name,
                    :return_type,
                    :parameter_type

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases

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
