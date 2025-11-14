# frozen_string_literal: true

module Lutaml
  module Xmi
    class PackageDrop < Liquid::Drop
      include Parsers::XmiBase

      def initialize(model, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        @model = model
        @guidance = guidance

        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]

        @packages = model.packaged_element.select do |e|
          e.type?("uml:Package")
        end

        @klasses = model.packaged_element.select do |e|
          e.type?("uml:Class") || e.type?("uml:AssociationClass") ||
            e.type?("uml:Interface")
        end

        @all_data_type_elements = []
        select_all_packaged_elements(@all_data_type_elements, model,
                                     "uml:DataType")

        @children_packages ||= packages.map do |pkg|
          [pkg, pkg.packages, pkg.packages.map(&:children_packages)]
        end.flatten.uniq
      end

      def xmi_id
        @model.id
      end

      def name
        get_package_name(@model)
      end

      def absolute_path
        absolute_path_arr = [@model.name]
        e = find_upper_level_packaged_element(@model.id)
        absolute_path_arr << e.name if e

        while e
          e = find_upper_level_packaged_element(e.id)
          absolute_path_arr << e.name if e
        end

        absolute_path_arr << "::#{@xmi_root_model.model.name}"
        absolute_path_arr.reverse.join("::")
      end

      def klasses # rubocop:disable Metrics/MethodLength
        @klasses.map do |klass|
          ::Lutaml::Xmi::KlassDrop.new(
            klass,
            @guidance,
            @options.merge(
              {
                absolute_path: "#{@options[:absolute_path]}::#{name}",
              },
            ),
          )
        end
      end
      alias classes klasses

      def enums
        enums = @model.packaged_element.select do |e|
          e.type?("uml:Enumeration")
        end

        enums.map do |enum|
          ::Lutaml::Xmi::EnumDrop.new(enum, @options)
        end
      end

      def data_types
        @all_data_type_elements.map do |data_type|
          ::Lutaml::Xmi::DataTypeDrop.new(data_type, @options)
        end
      end

      def diagrams
        diagrams = @xmi_root_model.extension.diagrams.diagram.select do |d|
          d.model.package == @model.id
        end

        diagrams.map do |diagram|
          ::Lutaml::Xmi::DiagramDrop.new(diagram, @options)
        end
      end

      def packages # rubocop:disable Metrics/MethodLength
        @packages.map do |package|
          ::Lutaml::Xmi::PackageDrop.new(
            package,
            @guidance,
            @options.merge(
              {
                absolute_path: "#{@options[:absolute_path]}::#{name}",
              },
            ),
          )
        end
      end

      def children_packages
        @children_packages
      end

      def definition
        doc_node_attribute_value(@model.id, "documentation")
      end

      def stereotype
        doc_node_attribute_value(@model.id, "stereotype")
      end
    end
  end
end
