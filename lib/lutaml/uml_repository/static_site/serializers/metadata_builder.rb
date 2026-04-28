# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class MetadataBuilder
          def initialize(repository)
            @repository = repository
          end

          def build
            {
              generated: Time.now.utc.iso8601,
              generator: "LutaML Static Site Generator",
              version: "1.0",
              statistics: build_statistics,
            }
          end

          private

          def build_statistics
            {
              packages: @repository.packages_index.size,
              classes: @repository.classes_index.size,
              associations: @repository.associations_index.size,
              attributes: count_total_attributes,
              operations: count_total_operations,
            }
          end

          def count_total_attributes
            @repository.classes_index.sum do |klass|
              klass.attributes&.size || 0
            end
          end

          def count_total_operations
            @repository.classes_index.sum do |klass|
              (klass.respond_to?(:operations) ? klass.operations&.size : 0) || 0
            end
          end
        end
      end
    end
  end
end
