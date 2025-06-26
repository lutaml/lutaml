# frozen_string_literal: true

module Lutaml
  module Uml
    class Model < Package
      attr_accessor :viewpoint

      def initialize # rubocop:disable Lint/MissingSuper
        @contents = []
      end
    end
  end
end
