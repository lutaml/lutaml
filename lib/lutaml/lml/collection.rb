# frozen_string_literal: true

module Lutaml
  module Lml
    class Collection < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :includes, :string, collection: true
      attribute :validations, :string, collection: true

      def initialize(data = {})
        @includes = data.dig(:includes, :list)&.map { |item| item[:string] }
        @validations = data.dig(:validations)&.map { |item| item.dig(:condition, :string) }
        @name = data.dig(:name, :string)
      end
    end
  end
end