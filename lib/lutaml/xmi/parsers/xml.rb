require "nokogiri"
require "htmlentities"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"
require "lutaml/xmi"
require "xmi"
require "lutaml/xmi/parsers/xmi_base"

module Lutaml
  module XMI
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class XML
        @xmi_cache_static = {}
        @xmi_root_model_cache_static = {}

        attr_reader :xmi_cache, :xmi_root_model, :all_packaged_elements_cache

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

          # @param xml [String] path to xml
          # @param name [String]
          # @param guidance [String]
          # @return [Hash]
          def serialize_generalization_by_name(xml, name, guidance = nil)
            # puts "#{xml}, #{name}, #{guidance}"

            # Load from cache or file
            xml_cache_key = (Digest::SHA256.file xml).hexdigest
            xmi_model = deep_clone(@xmi_root_model_cache_static[xml_cache_key])
            xmi_model_to_cache = nil
            if xmi_model == nil
              xmi_model = get_xmi_model(xml)
              xmi_model_to_cache = deep_clone(xmi_model)
            end
            xmi_cache = @xmi_cache_static[xml_cache_key]

            instance = new
            ret_val = instance.serialize_generalization_by_name(xmi_model, name, guidance, xmi_cache)

            # Put to cache
            @xmi_cache_static[xml_cache_key] = instance.xmi_cache if guidance == nil
            @xmi_root_model_cache_static[xml_cache_key] = xmi_model_to_cache if xmi_model_to_cache

            ret_val
          end

          def deep_clone(obj)
            # TODO: we need this if xmi_model is being modified in serialize_generalization_by_name
            #Marshal.load(Marshal.dump(obj)) if obj != nil
            obj
          end
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @return [Lutaml::Uml::Document]
        def parse(xmi_model)
          set_xmi_model(xmi_model)
          serialized_hash = serialize_xmi(xmi_model)

          ::Lutaml::Uml::Document.new(serialized_hash)
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
            xmi_cache: @xmi_cache,
            with_gen: true,
            with_absolute_path: true,
          }
          ::Lutaml::XMI::RootDrop.new(model, guidance, options)
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param name [String]
        # @param guidance_yaml [String]
        # @return [Hash]
        def serialize_generalization_by_name(xmi_model, name, # rubocop:disable Metrics/MethodLength
                                             guidance = nil, xmi_cache = nil)
          set_xmi_model(xmi_model, xmi_cache)
          klass = find_klass_packaged_element(name)
          options = {
            xmi_root_model: @xmi_root_model,
            xmi_cache: @xmi_cache,
            with_gen: true,
            with_absolute_path: true,
          }
          ::Lutaml::XMI::KlassDrop.new(
            klass,
            guidance,
            options,
          )
        end
      end
    end
  end
end
