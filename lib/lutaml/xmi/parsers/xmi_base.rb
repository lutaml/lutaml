# frozen_string_literal: true

require "nokogiri"
require "htmlentities"
require "xmi"
require "digest"
require_relative "xmi_connector"
require_relative "xmi_diagram"
require_relative "xmi_generalization"
require_relative "xmi_enum_data_type"
require_relative "xmi_class_members"

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          private

          # @param xml [String]
          # @return [Lutaml::Model::Serializable]
          def get_xmi_model(xml)
            ::Xmi::Sparx::Root.parse_xml(File.read(xml))
          end
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param id_name_mapping [Hash]
        # @return [Hash]
        def set_xmi_model(xmi_model, id_name_mapping = nil)
          @xmi_root_model ||= xmi_model

          if @xmi_index.nil?
            @xmi_index = @xmi_root_model.index
            @id_name_mapping = id_name_mapping || @xmi_index.id_name_map
          end
        end

        # Access the index, auto-initializing from @xmi_root_model if needed
        def xmi_index
          if @xmi_index.nil? && @xmi_root_model
            @xmi_index = @xmi_root_model.index
            @id_name_mapping ||= @xmi_index.id_name_map
          end
          @xmi_index
        end

        private

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @return [Hash]
        # @note xpath: //uml:Model[@xmi:type="uml:Model"]
        def serialize_to_hash(xmi_model,
          with_gen: false, with_absolute_path: false)
          model = xmi_model.model
          {
            name: model.name,
            packages: serialize_model_packages(
              model,
              with_gen: with_gen,
              with_absolute_path: with_absolute_path,
            ),
          }
        end

        # @param model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @param absolute_path: [String]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Package"]
        def serialize_model_packages(model, # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          with_gen: false, with_absolute_path: false, absolute_path: "")
          packages = model.packaged_element.select do |e|
            e.type?("uml:Package")
          end

          if with_absolute_path
            absolute_path = "#{absolute_path}::#{model.name}"
          end

          packages.map do |package| # rubocop:disable Metrics/BlockLength
            h = {
              xmi_id: package.id,
              name: get_package_name(package),
              classes: serialize_model_classes(
                package, model,
                with_gen: with_gen,
                with_absolute_path: with_absolute_path,
                absolute_path: "#{absolute_path}::#{package.name}"
              ),
              enums: serialize_model_enums(package),
              data_types: serialize_model_data_types(package),
              diagrams: serialize_model_diagrams(
                package.id,
                with_package: with_gen,
              ),
              packages: serialize_model_packages(
                package,
                with_gen: with_gen,
                with_absolute_path: with_absolute_path,
                absolute_path: absolute_path,
              ),
              definition: doc_node_attribute_value(package.id, "documentation"),
              stereotype: doc_node_attribute_value(package.id, "stereotype"),
            }

            if with_absolute_path
              h[:absolute_path] = "#{absolute_path}::#{package.name}"
            end

            h
          end
        end

        # @param package [Lutaml::Model::Serializable]
        # @return [String]
        def get_package_name(package) # rubocop:disable Metrics/AbcSize
          return package.name unless package.name.nil?

          connector = fetch_connector(package.id)
          if connector.target&.model&.name
            return "#{connector.target.model.name} " \
                   "(#{package.type.split(':').last})"
          end

          "unnamed"
        end

        # @param package [Lutaml::Model::Serializable]
        # @param model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Class" or
        #                               @xmi:type="uml:AssociationClass"]
        def serialize_model_classes(package, model, # rubocop:disable Metrics/MethodLength
          with_gen: false, with_absolute_path: false, absolute_path: "")
          klasses = package.packaged_element.select do |e|
            e.type?("uml:Class") || e.type?("uml:AssociationClass") ||
              e.type?("uml:Interface")
          end

          klasses.map do |klass|
            build_klass_hash(
              klass, model,
              with_gen: with_gen,
              with_absolute_path: with_absolute_path,
              absolute_path: absolute_path
            )
          end
        end

        # @param klass [Lutaml::Model::Serializable]
        # @param model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @return [Hash]
        def build_klass_hash(klass, model, # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity
          with_gen: false, with_absolute_path: false, absolute_path: "")
          klass_hash = {
            xmi_id: klass.id,
            name: klass.name,
            package: model,
            type: klass.type.split(":").last,
            attributes: serialize_class_attributes(klass),
            associations: serialize_model_associations(klass.id),
            operations: serialize_class_operations(klass),
            constraints: serialize_class_constraints(klass.id),
            is_abstract: doc_node_attribute_value(klass.id, "isAbstract"),
            definition: doc_node_attribute_value(klass.id, "documentation"),
            stereotype: doc_node_attribute_value(klass.id, "stereotype"),
          }

          klass_hash[:absolute_path] = absolute_path if with_absolute_path

          if with_gen && klass.type?("uml:Class")
            klass_hash[:generalization] = serialize_generalization(klass)
          end

          if klass.generalization && !klass.generalization.empty?
            klass_hash[:association_generalization] = []
            klass.generalization.each do |gen|
              klass_hash[:association_generalization] << {
                id: gen.id,
                type: gen.type,
                general: gen.general,
              }
            end
          end

          klass_hash
        end

        # @param id [String]
        # @return [Lutaml::Model::Serializable]
        def find_packaged_element_by_id(id)
          xmi_index.find_packaged_element(id)
        end

        # @param id [String]
        # @return [Lutaml::Model::Serializable]
        def find_upper_level_packaged_element(klass_id)
          xmi_index.find_parent(klass_id)
        end

        def find_subtype_of_from_owned_attribute_type(id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          @pkg_elements_owned_attributes ||= begin
            cache = {}
            all_packaged_elements.each do |e|
              next unless e.owned_attribute

              e.owned_attribute.each do |oa|
                next unless oa.association && oa.uml_type && oa.uml_type.idref

                cache[oa.uml_type.idref] = e.name
              end
            end
            cache
          end

          @pkg_elements_owned_attributes[id]
        end

        def find_subtype_of_from_generalization(id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          matched_element = xmi_index.find_element(id)

          return unless matched_element&.links&.any?

          matched_generalization = nil
          matched_element.links.each do |link|
            matched_generalization = link&.generalization&.find do |g|
              g.start == id
            end
            break if matched_generalization
          end

          return if matched_generalization&.end.nil?

          lookup_entity_name(matched_generalization.end)
        end

        # @param path [String]
        # @return [Lutaml::Model::Serializable]
        def find_klass_packaged_element(path)
          lutaml_path = Lutaml::Path.parse(path)
          if lutaml_path.segments.one?
            return find_klass_packaged_element_by_name(path)
          end

          find_klass_packaged_element_by_path(lutaml_path)
        end

        # @param path [Lutaml::Path::ElementPath]
        # @return [Lutaml::Model::Serializable]
        def find_klass_packaged_element_by_path(path)
          if path.absolute?
            iterate_packaged_element(
              @xmi_root_model.model, path.segments.map(&:name)
            )
          else
            iterate_relative_packaged_element(path.segments.map(&:name))
          end
        end

        # @param name_array [Array<String>]
        # @return [Lutaml::Model::Serializable]
        def iterate_relative_packaged_element(name_array)
          # match the first element in the name_array using index
          matched_elements = xmi_index.packaged_elements_of_type("uml:Package")
            .select { |e| e.name == name_array[0] }

          # match the rest elements in the name_array
          result = matched_elements.map do |e|
            iterate_packaged_element(e, name_array, type: "uml:Class")
          end

          result.compact.first
        end

        # @param model [Lutaml::Model::Serializable]
        # @param name_array [Array<String>]
        # @param index: [Integer]
        # @param type: [String]
        # @return [Lutaml::Model::Serializable]
        def iterate_packaged_element(model, name_array,
          index: 1, type: "uml:Package")
          return model if index == name_array.count

          model = model.packaged_element.find do |p|
            p.name == name_array[index] && p.type?(type)
          end

          return nil if model.nil?

          index += 1
          type = index == name_array.count - 1 ? "uml:Class" : "uml:Package"
          iterate_packaged_element(model, name_array, index: index, type: type)
        end

        # @param name [String]
        # @return [Lutaml::Model::Serializable]
        def find_klass_packaged_element_by_name(name)
          xmi_index.find_packaged_by_name_and_types(
            name,
            ["uml:Class", "uml:AssociationClass"],
          )
        end

        # @param name [String]
        # @return [Lutaml::Model::Serializable]
        def find_enum_packaged_element_by_name(name)
          xmi_index.packaged_elements_of_type("uml:Enumeration")
            .find { |e| e.name == name }
        end

        # @param supplier_id [String]
        # @return [Lutaml::Model::Serializable]
        def select_dependencies_by_supplier(supplier_id)
          xmi_index.packaged_elements_of_type("uml:Dependency")
            .select { |e| e.supplier == supplier_id }
        end

        # @param supplier_id [String]
        # @return [Lutaml::Model::Serializable]
        def select_dependencies_by_client(client_id)
          xmi_index.packaged_elements_of_type("uml:Dependency")
            .select { |e| e.client == client_id }
        end

        # @param name [String]
        # @return [Lutaml::Model::Serializable]
        def find_packaged_element_by_name(name)
          xmi_index.packaged_elements.find { |e| e.name == name }
        end

        # @node [Lutaml::Model::Serializable]
        # @attr_name [String]
        # @return [String]
        # @note xpath %(//element[@xmi:idref="#{xmi_id}"]/properties)
        def doc_node_attribute_value(node_id, attr_name)
          doc_node = fetch_element(node_id)
          return unless doc_node

          doc_node.properties&.send(
            Lutaml::Model::Utils.snake_case(attr_name).to_sym,
          )
        end

        # @param xmi_id [String]
        # @return [Lutaml::Model::Serializable]
        # @note xpath %(//attribute[@xmi:idref="#{xmi_id}"])
        def fetch_attribute_node(xmi_id)
          xmi_index.find_attribute(xmi_id)
        end

        # @param xmi_id [String]
        # @return [String]
        # @note xpath %(//attribute[@xmi:idref="#{xmi_id}"]/documentation)
        def lookup_attribute_documentation(xmi_id)
          attribute_node = fetch_attribute_node(xmi_id)

          return unless attribute_node&.documentation

          attribute_node&.documentation&.value
        end

        # @param xmi_id [String]
        # @return [String]
        def lookup_element_prop_documentation(xmi_id)
          element_node = xmi_index.find_element(xmi_id)

          return unless element_node&.properties

          element_node.properties.documentation
        end

        # @param xmi_id [String]
        # @return [String]
        def lookup_entity_name(xmi_id)
          @id_name_mapping[xmi_id]
        end

        # @note Removed: model_node_name_by_xmi_id - replaced by Xmi::Index

        # @return [Array<::Xmi::Uml::PackagedElement>]
        def all_packaged_elements
          xmi_index.packaged_elements
        end

        # @param items [Array<Lutaml::Model::Serializable>]
        # @param model [Lutaml::Model::Serializable]
        # @param type [String] nil for any
        def select_all_items(items, model, type, method)
          iterate_tree(items, model, type, method.to_sym)
        end

        # @param all_elements [Array<Lutaml::Model::Serializable>]
        # @param model [Lutaml::Model::Serializable]
        # @param type [String] nil for any
        # @note xpath ./packagedElement[@xmi:type="#{type}"]
        def select_all_packaged_elements(all_elements, model, type)
          select_all_items(all_elements, model, type, :packaged_element)
          all_elements.delete_if do |e|
            !e.is_a?(::Xmi::Uml::PackagedElement)
          end
        end

        # @param result [Array<Lutaml::Model::Serializable>]
        # @param node [Lutaml::Model::Serializable]
        # @param type [String] nil for any
        # @param children_method [String] method to determine children exist
        def iterate_tree(result, node, type, children_method) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          result << node if type.nil? || node.type == type
          return unless node.send(children_method.to_sym)

          node.send(children_method.to_sym).each do |sub_node|
            if sub_node.send(children_method.to_sym)
              iterate_tree(result, sub_node, type, children_method)
            elsif type.nil? || sub_node.type == type
              result << sub_node
            end
          end
        end

        # @note Removed: map_id_name - replaced by Xmi::Index
      end
    end
  end
end
