# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      class DataTransformer
        include Lutaml::Uml::ModelHelpers

        attr_reader :repository, :id_generator, :options

        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IdGenerator.new
          @generalization_map = build_generalization_map
        end

        def transform
          Models::SpaDocument.new(
            metadata: Serializers::MetadataBuilder.new(repository,
                                                       @options[:config]).build,
            package_tree: build_package_tree,
            packages: build_packages_map,
            classes: build_classes_map,
            attributes: build_attributes_map,
            associations: build_associations_map,
            operations: build_operations_map,
            diagrams: build_diagrams_map,
          )
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
            add_generalization_entries(map, klass)
          end

          map
        end

        def class_lookup
          @class_lookup ||= ClassLookupIndex.new(repository.classes_index)
        end

        def build_package_tree
          Serializers::PackageTreeBuilder.new(repository, id_generator).build
        end

        def build_packages_map
          Serializers::PackageSerializer.new(repository, id_generator,
                                             options).build_map
        end

        def build_classes_map
          Serializers::ClassSerializer.new(repository, id_generator,
                                           options, inheritance_resolver).build_map
        end

        def build_attributes_map
          Serializers::AttributeSerializer.new(repository, id_generator,
                                               options).build_map
        end

        def build_associations_map
          Serializers::AssociationSerializer.new(repository, id_generator,
                                                 options).build_map
        end

        def build_operations_map
          Serializers::OperationSerializer.new(repository,
                                               id_generator).build_map
        end

        def build_diagrams_map
          return {} unless options[:include_diagrams]

          Serializers::DiagramSerializer.new(repository, id_generator,
                                             options).build_map
        end

        def add_generalization_entries(map, klass)
          return unless klass.association_generalization
          return if klass.association_generalization.empty?

          klass.association_generalization.each do |assoc_gen|
            add_valid_generalization_entry(map, klass, assoc_gen)
          end
        end

        def add_valid_generalization_entry(map, klass, assoc_gen)
          parent_xmi_id = resolve_parent_xmi_id(assoc_gen)
          return unless parent_xmi_id
          return if parent_xmi_id == klass.xmi_id
          return if map[klass.xmi_id].include?(parent_xmi_id)

          map[klass.xmi_id] << parent_xmi_id
        end

        def resolve_parent_xmi_id(assoc_gen)
          return nil unless assoc_gen

          if assoc_gen.is_a?(String)
            return nil if assoc_gen.empty?

            found = class_lookup.by_xmi_id(assoc_gen)
            return found ? assoc_gen : nil
          end

          parent_object_id = assoc_gen.parent_object_id
          return nil unless parent_object_id

          parent_class = class_lookup.by_object_id(parent_object_id)
          parent_class&.xmi_id
        end
      end
    end
  end
end
