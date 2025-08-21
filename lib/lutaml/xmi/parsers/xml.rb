require "nokogiri"
require "htmlentities"
require "lutaml/xmi"
require "xmi"
require "lutaml/xmi/parsers/xmi_base"
require "lutaml/uml"
require "lutaml/converter/xmi_hash_to_uml"

module Lutaml
  module XMI
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class XML
        include Lutaml::Converter::XmiHashToUml

        @id_name_mapping_static = {}
        @xmi_root_model_cache_static = {}

        attr_reader :id_name_mapping, :xmi_root_model,
                    :all_packaged_elements_cache

        include XMIBase

        class << self
          # @param xml [String] path to xml
          # @param options [Hash] options for parsing
          # @return [Lutaml::Uml::Document]
          def parse(xml, _options = {})
            xmi_model = get_xmi_model(xml)
            new.parse(xmi_model)
          end

          # @param xml [String] path to xml
          # @param with_gen [Boolean]
          # @return [Hash]
          def serialize_xmi(xml, with_gen: false)
            xmi_model = get_xmi_model(xml)
            new.serialize_xmi(xmi_model, with_gen: with_gen)
          end

          # @param xml [String] path to xml
          # @return [Liquid::Drop]
          def serialize_xmi_to_liquid(xml, guidance = nil)
            xmi_model = get_xmi_model(xml)
            new.serialize_xmi_to_liquid(xmi_model, guidance)
          end

          # @param xmi_path [String] path to xml
          # @param name [String]
          # @param guidance [String]
          # @return [Hash]
          def serialize_generalization_by_name( # rubocop:disable Metrics/MethodLength
            xmi_path, name, guidance = nil
          )
            # Load from cache or file
            xml_cache_key = (Digest::SHA256.file xmi_path).hexdigest
            xmi_model = @xmi_root_model_cache_static[xml_cache_key] ||
              get_xmi_model(xmi_path)
            id_name_mapping = @id_name_mapping_static[xml_cache_key]

            instance = new
            ret_val = instance.serialize_generalization_by_name(
              xmi_model, name, guidance, id_name_mapping
            )

            # Put xmi_model and id_name_mapping to cache
            @id_name_mapping_static[xml_cache_key] ||= instance.id_name_mapping
            @xmi_root_model_cache_static[xml_cache_key] ||= xmi_model

            ret_val
          end

          # @param xmi_path [String] path to xml
          # @param name [String]
          # @return [Hash]
          def serialize_enumeration_by_name( # rubocop:disable Metrics/MethodLength
            xmi_path, name
          )
            # Load from cache or file
            xml_cache_key = (Digest::SHA256.file xmi_path).hexdigest
            xmi_model = @xmi_root_model_cache_static[xml_cache_key] ||
              get_xmi_model(xmi_path)
            id_name_mapping = @id_name_mapping_static[xml_cache_key]

            instance = new
            enum = instance.serialize_enumeration_by_name(
              xmi_model, name, id_name_mapping
            )

            # Put xmi_model and id_name_mapping to cache
            @id_name_mapping_static[xml_cache_key] ||= instance.id_name_mapping
            @xmi_root_model_cache_static[xml_cache_key] ||= xmi_model

            enum
          end
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @return [Lutaml::Uml::Document]
        def parse(xmi_model)
          set_xmi_model(xmi_model)
          serialized_hash = serialize_xmi(xmi_model)
          create_uml_document(serialized_hash)
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # return [Hash]
        def serialize_xmi(xmi_model, with_gen: false, with_absolute_path: false)
          set_xmi_model(xmi_model)
          serialize_to_hash(
            xmi_model,
            with_gen: with_gen,
            with_absolute_path: with_absolute_path,
          )
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param guidance_yaml [String]
        # return [Liquid::Drop]
        def serialize_xmi_to_liquid(xmi_model, guidance = nil)
          set_xmi_model(xmi_model)
          model = xmi_model.model
          options = {
            xmi_root_model: @xmi_root_model,
            id_name_mapping: @id_name_mapping,
            with_gen: true,
            with_absolute_path: true,
          }
          ::Lutaml::XMI::RootDrop.new(model, guidance, options)
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param name [String]
        # @param guidance_yaml [String]
        # @param id_name_mapping [Hash]
        # @return [Hash]
        def serialize_generalization_by_name( # rubocop:disable Metrics/MethodLength
          xmi_model, name, guidance = nil, id_name_mapping = nil
        )
          set_xmi_model(xmi_model, id_name_mapping)
          klass = find_klass_packaged_element(name)
          options = {
            xmi_root_model: @xmi_root_model,
            id_name_mapping: @id_name_mapping,
            with_gen: true,
            with_absolute_path: true,
          }
          puts "Error: Class not found for name: #{name}!" if klass.nil?
          ::Lutaml::XMI::KlassDrop.new(
            klass,
            guidance,
            options,
          )
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param name [String]
        # @param id_name_mapping [Hash]
        # @return [Hash]
        def serialize_enumeration_by_name( # rubocop:disable Metrics/MethodLength
          xmi_model, name, id_name_mapping = nil
        )
          set_xmi_model(xmi_model, id_name_mapping)
          enum = find_enum_packaged_element_by_name(name)
          options = {
            xmi_root_model: @xmi_root_model,
            id_name_mapping: @id_name_mapping,
            with_gen: true,
            with_absolute_path: true,
          }
          puts "Error: Enumeration not found for name: #{name}!" if enum.nil?
          ::Lutaml::XMI::EnumDrop.new(enum, options)
        end
      end
    end
  end
end
