# frozen_string_literal: true

module Lutaml
  module Uml
    class Collection
      attr_accessor :name, :includes, :validations

      def initialize(attributes)
        @name = attributes.dig(:name, :string)
        @includes = attributes.dig(:includes, :list)&.map { |item| item[:string] }
        @validations = attributes[:validations]&.map { |item| item.dig(:condition, :string) }
      end
    end
  end
end
