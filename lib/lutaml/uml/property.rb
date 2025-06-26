# frozen_string_literal: true

module Lutaml
  module Uml
    class Property < TopElement
      attr_accessor :type, # rubocop:disable Naming/MethodName
                    :aggregation,
                    :association,
                    :is_derived,
                    :lowerValue,
                    :upperValue

      def initialize # rubocop:disable Lint/MissingSuper
        @name = nil
        @xmi_id = nil
        @xmi_uuid = nil
        @aggregation = nil
        @association = nil
        @namespace = nil
        @is_derived = false
        @visibility = "public"
        @lowerValue = "1" # rubocop:disable Naming/VariableName
        @upperValue = "1" # rubocop:disable Naming/VariableName
      end
    end
  end
end
