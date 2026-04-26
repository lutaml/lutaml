# frozen_string_literal: true

require "nokogiri"
require "htmlentities"
require "xmi"
require_relative "xmi_base"
require_relative "../xmi_lookup_service"
require "lutaml/converter/xmi_to_uml"

module Lutaml
  module Xmi
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class Xml
        include Lutaml::Converter::XmiToUml

        attr_reader :id_name_mapping, :xmi_root_model

        include XmiBase

        class << self
          # @param xml [String] path to xml
          # @param options [Hash] options for parsing
          # @return [Lutaml::Uml::Document]
          def parse(xml, _options = {})
            xmi_model = get_xmi_model(xml)
            new.parse(xmi_model)
          end

          # @param xml [String] path to xml
          # @return [Liquid::Drop]
          def serialize_xmi_to_liquid(xml, guidance = nil)
            xmi_model = get_xmi_model(xml)
            new.serialize_xmi_to_liquid(xmi_model, guidance)
          end
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @return [Lutaml::Uml::Document]
        def parse(xmi_model)
          set_xmi_model(xmi_model)
          create_uml_document(xmi_model)
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param guidance_yaml [String]
        # return [Liquid::Drop]
        def serialize_xmi_to_liquid(xmi_model, guidance = nil)
          set_xmi_model(xmi_model)
          uml_document = create_uml_document(xmi_model)
          lookup = XmiLookupService.new(@xmi_root_model, @id_name_mapping)
          options = {
            xmi_root_model: @xmi_root_model,
            id_name_mapping: @id_name_mapping,
            lookup: lookup,
            with_gen: true,
            with_absolute_path: true,
          }
          ::Lutaml::Xmi::LiquidDrops::RootDrop.new(uml_document, guidance,
                                                   options)
        end
      end
    end
  end
end
