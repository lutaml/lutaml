# frozen_string_literal: true

require_relative "../../../uml/model_helpers"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class PackageSerializer
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator, options)
            @repository = repository
            @id_generator = id_generator
            @options = options
          end

          def build_map
            packages = {}
            @repository.packages_index.each do |package|
              id = @id_generator.package_id(package)
              packages[id] = serialize(package, id)
            end
            packages
          end

          private

          def serialize(package, id)
            {
              id: id,
              xmiId: package.respond_to?(:xmi_id) ? package.xmi_id : nil,
              name: package.name,
              path: package_path(package),
              definition: format_definition(
                package.respond_to?(:definition) ? package.definition : nil,
              ),
              stereotypes: normalize_stereotypes(
                package.respond_to?(:stereotype) ? package.stereotype : nil,
              ),
              classes: (package.classes || []).map { |c| @id_generator.class_id(c) },
              subPackages: (package.packages || []).map { |p| @id_generator.package_id(p) },
              diagrams: package_diagrams(package).map { |d| @id_generator.diagram_id(d) },
              parent: if package.respond_to?(:namespace) &&
                  package.namespace.is_a?(Lutaml::Uml::Package)
                        @id_generator.package_id(package.namespace)
                      end,
            }
          end

          def package_path(package)
            unless package.respond_to?(:namespace) && package.namespace
              return package.name
            end
            return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

            "#{package_path(package.namespace)}::#{package.name}"
          end

          def package_diagrams(package)
            return [] unless @options[:include_diagrams]
            package.diagrams || []
          rescue StandardError => e
            warn "Error getting diagrams for #{package.name}: #{e.message}"
            []
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
end
