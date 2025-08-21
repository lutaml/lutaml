# frozen_string_literal: true

require 'pry'

module Lutaml
  module Lml
    class DocumentRequire
      attr_reader :value

      def self.cast(value)
        value
      end

      def initialize(value)
        @value = value.dig(:require, :string)
      end
    end
  end
end