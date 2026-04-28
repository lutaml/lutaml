# frozen_string_literal: true

require_relative "id_generator"
require_relative "../../uml/model_helpers"
require_relative "../class_lookup_index"
require_relative "association_serialization"
require_relative "serializers/metadata_builder"
require_relative "serializers/package_tree_builder"
require_relative "serializers/package_serializer"
require_relative "serializers/class_serializer"
require_relative "serializers/attribute_serializer"
require_relative "serializers/operation_serializer"
require_relative "serializers/diagram_serializer"
require_relative "serializers/inheritance_resolver"

module Lutaml
  module UmlRepository
    module StaticSite
      class DataTransformer
        include AssociationSerialization
        include Lutaml::Uml::ModelHelpers

        attr_reader :repository, :id_generator, :options

        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IDGenerator.new
          @generalization_map = build_generalization_map
        end

        def transform
          {
            metadata: Serializers::MetadataBuilder.new(repository).build,
            packageTree: Serializers::PackageTreeBuilder.new(repository, id_generator).build,
            packages: Serializers::PackageSerializer.new(repository, id_generator, options).build_map,
            classes: Serializers::ClassSerializer.new(repository, id_generator, options, inheritance_resolver).build_map,
            attributes: Serializers::AttributeSerializer.new(repository, id_generator, options).build_map,
            associations: build_associations_map,
            operations: Serializers::OperationSerializer.new(repository, id_generator).build_map,
            diagrams: (options[:include_diagrams] ? Serializers::DiagramSerializer.new(repository, id_generator, options).build_map : {}),
          }
        end

        private

        def default_options
          {
            include_diagrams: true,
            format_definitions: true,
            max_definition_length: nil,
          }
        end

        def inheritance_resolver
          @inheritance_resolver ||= Serializers::InheritanceResolver.new(
            repository, id_generator, options, @generalization_map
          )
        end

        def build_generalization_map
          map = Hash.new { |h, k| h[k] = [] }

          repository.classes_index.each do |klass|
            next unless klass.respond_to?(:association_generalization)
            unless klass.association_generalization && !klass.association_generalization.empty?
              next
            end

            klass.association_generalization.each do |assoc_gen|
              next unless assoc_gen.respond_to?(:parent_object_id)
              parent_object_id = assoc_gen.parent_object_id
              next unless parent_object_id

              parent_class = class_lookup.by_object_id(parent_object_id)
              if parent_class&.xmi_id
                next if parent_class.xmi_id == klass.xmi_id
                unless map[klass.xmi_id].include?(parent_class.xmi_id)
                  map[klass.xmi_id] << parent_class.xmi_id
                end
              end
            end
          end

          map
        end

        def class_lookup
          @class_lookup ||= ClassLookupIndex.new(repository.classes_index)
        end

        def find_class_by_xmi_id(xmi_id)
          return nil unless xmi_id
          class_lookup.by_xmi_id(xmi_id)
        rescue StandardError
          nil
        end

        def find_class_by_object_id(object_id)
          return nil unless object_id
          class_lookup.by_object_id(object_id)
        rescue StandardError
          nil
        end

        def serialize_cardinality(cardinality)
          return nil unless cardinality

          {
            min: cardinality.min,
            max: cardinality.max,
          }
        end

        def format_definition(definition)
          return nil if definition.nil? || definition.empty?
          formatted = definition.strip
          if @options[:max_definition_length] &&
              formatted.length > @options[:max_definition_length]
            formatted = "#{formatted[0...@options[:max_definition_length]]}..."
          end
          if @options[:format_definitions]
            formatted = formatted.gsub(%r{(https?://[^\s]+)}, '[\1](\1)')
          end
          formatted
        end
      end
    end
  end
end
