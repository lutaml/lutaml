# frozen_string_literal: true

module Lutaml
  module Uml
    class Property < TopElement
      attr_accessor :type,
                    :aggregation,
                    :association,
                    :is_derived,
                    :lowerValue,
                    :upperValue

      def initialize
        @name = nil
        @xmi_id = nil
        @xmi_uuid = nil
        @aggregation = nil
        @association = nil
        @namespace = nil
        @is_derived = false
        @visibility = "public"
        @lowerValue = "1"
        @upperValue = "1"
      end
    end
  end
end
