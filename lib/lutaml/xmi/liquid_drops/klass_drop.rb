# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class KlassDrop < Liquid::Drop
        def initialize(model, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          @model = model
          @guidance = guidance
          @options = options
          @lookup = options[:lookup]
          @xmi_root_model = options[:xmi_root_model]
          @id_name_mapping = options[:id_name_mapping]

          if @xmi_root_model
            @clients_dependencies = @lookup.select_dependencies_by_supplier(@model.xmi_id)
            @suppliers_dependencies = @lookup.select_dependencies_by_client(@model.xmi_id)

            matched_element = @lookup.find_matched_element(@model.xmi_id)
            @inheritance_ids = matched_element&.links&.map do |link|
              link.generalization.select do |gen|
                gen.end == @model.xmi_id
              end.map(&:id)
            end&.flatten&.compact || []
          end

          if guidance
            @klass_guidance = guidance["classes"].find do |klass|
              klass["name"] == name || klass["name"] == absolute_path
            end
          end
        end

        def xmi_id
          @model.xmi_id
        end

        def name
          @model.name
        end

        def absolute_path
          absolute_path_arr = [@model.name]
          e = @lookup.find_upper_level_packaged_element(@model.xmi_id)
          absolute_path_arr << e.name if e

          while e
            e = @lookup.find_upper_level_packaged_element(e.id)
            absolute_path_arr << e.name if e
          end

          absolute_path_arr << "::#{@xmi_root_model.model.name}"
          absolute_path_arr.reverse.join("::")
        end

        def package
          nested_pkg = @lookup.find_packaged_element_by_id(@model.xmi_id)
          return unless nested_pkg

          xmi_pkg = nested_pkg.packaged_element&.find do |e|
            e.type?("uml:Package")
          end
          return unless xmi_pkg

          uml_pkg = ::Lutaml::Uml::Package.new
          uml_pkg.xmi_id = xmi_pkg.id
          uml_pkg.name = @lookup.get_package_name(xmi_pkg)
          ::Lutaml::Xmi::LiquidDrops::PackageDrop.new(
            uml_pkg,
            @guidance,
            @options.merge(
              {
                absolute_path: "#{@options[:absolute_path]}::#{name}",
              },
            ),
          )
        end

        def type
          @model.type
        end

        def attributes
          @model.attributes.filter_map do |owned_attr|
            if @options[:with_assoc] || owned_attr.association.nil?
              ::Lutaml::Xmi::LiquidDrops::AttributeDrop.new(owned_attr,
                                                            @options)
            end
          end
        end

        def owned_attributes
          @model.attributes.filter_map do |owned_attr|
            ::Lutaml::Xmi::LiquidDrops::AttributeDrop.new(owned_attr, @options)
          end
        end

        def suppliers_dependencies
          @suppliers_dependencies.filter_map do |dependency|
            ::Lutaml::Xmi::LiquidDrops::DependencyDrop.new(dependency, @options)
          end
        end

        def clients_dependencies
          @clients_dependencies.filter_map do |dependency|
            ::Lutaml::Xmi::LiquidDrops::DependencyDrop.new(dependency, @options)
          end
        end

        def inheritances
          @inheritance_ids.filter_map do |inheritance_id|
            connector = @lookup.fetch_connector(inheritance_id)
            ::Lutaml::Xmi::LiquidDrops::ConnectorDrop.new(connector, @options)
          end
        end

        def associations
          @model.associations.filter_map do |assoc|
            ::Lutaml::Xmi::LiquidDrops::AssociationDrop.new(assoc, @options)
          end
        end

        def operations
          @model.operations.map do |operation|
            ::Lutaml::Xmi::LiquidDrops::OperationDrop.new(operation)
          end
        end

        def constraints
          @model.constraints.map do |constraint|
            ::Lutaml::Xmi::LiquidDrops::ConstraintDrop.new(constraint)
          end
        end

        def generalization
          if @options[:with_gen] && @model.generalization
            ::Lutaml::Xmi::LiquidDrops::GeneralizationDrop.new(
              @model.generalization, @klass_guidance, @options
            )
          end
        end

        def upper_packaged_element
          if @options[:with_gen]
            e = @lookup.find_upper_level_packaged_element(@model.xmi_id)
            e&.name
          end
        end

        def subtype_of
          @lookup.find_subtype_of_from_generalization(@model.xmi_id) ||
            @lookup.find_subtype_of_from_owned_attribute_type(@model.xmi_id)
        end

        def has_guidance?
          !!@klass_guidance
        end

        def is_abstract # rubocop:disable Naming/PredicateName,Naming/PredicatePrefix
          @model.is_abstract
        end

        def definition
          @model.definition
        end

        def stereotype
          @model.stereotype&.first
        end
      end
    end
  end
end
