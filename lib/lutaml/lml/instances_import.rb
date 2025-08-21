# frozen_string_literal: true

require 'lutaml/lml/top_element_attribute'

module Lutaml
  module Lml
    class InstancesImport < Lutaml::Model::Serializable
      attribute :format_type, :string
      attribute :file, :string
      attribute :attributes, TopElementAttribute

      def initialize(data = {})
        data[:file] = extract_file_string(data[:file])

        super(data)
      end

      private

      def extract_file_string(file)
        file.is_a?(Hash) && file.key?(:string) ? file[:string] : file
      end
    end
  end
end