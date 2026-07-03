# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class Base
          include Lutaml::Uml::ModelHelpers

          attr_reader :repository, :id_generator, :options

          def initialize(repository, id_generator, options = {})
            @repository = repository
            @id_generator = id_generator
            @options = options
          end

          def class_lookup
            @class_lookup ||= ClassLookupIndex.new(@repository.classes_index)
          end

          def find_class_associations(klass)
            associations = @repository.associations_of(klass)
            associations.map { |assoc| @id_generator.association_id(assoc) }
          rescue StandardError
            []
          end

          def find_assoc_by_id(assoc_id)
            @repository.associations_index.find do |a|
              @id_generator.association_id(a) == assoc_id
            end
          end

          def resolve_assoc_role(assoc, xmi_id)
            if assoc.owner_end_xmi_id == xmi_id
              assoc.owner_end_attribute_name || assoc.owner_end || ""
            elsif assoc.member_end_xmi_id == xmi_id
              assoc.member_end_attribute_name || assoc.member_end || ""
            else
              ""
            end
          end

          def package_diagrams(package)
            return [] unless @options[:include_diagrams]

            package.diagrams || []
          rescue StandardError => e
            warn "Error getting diagrams for #{package.name}: #{e.message}"
            []
          end

          def serialize_attribute(attribute, owner, _id)
            Models::SpaAttribute.from_uml(
              attribute, owner,
              id_generator: @id_generator,
              definition: format_definition(attribute.definition, @options),
              stereotypes: normalize_stereotypes(attribute.stereotype)
            )
          end
        end
      end
    end
  end
end
