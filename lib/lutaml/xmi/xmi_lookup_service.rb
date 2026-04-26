# frozen_string_literal: true

require_relative "parsers/xmi_base"

module Lutaml
  module Xmi
    # Single bridge between Liquid Drop classes and the XMI document tree.
    # Drops receive an instance of this service instead of including XmiBase directly.
    class XmiLookupService
      include Parsers::XmiBase

      def initialize(xmi_root_model, id_name_mapping)
        @xmi_root_model = xmi_root_model
        @id_name_mapping = id_name_mapping
      end

      # XmiBase methods are private by default; expose as public API for Drops
      public :doc_node_attribute_value,
             :lookup_entity_name,
             :lookup_attribute_documentation,
             :find_upper_level_packaged_element,
             :find_packaged_element_by_id,
             :get_ns_by_xmi_id,
             :loopup_assoc_def,
             :fetch_connector,
             :fetch_definition_node_value,
             :select_dependencies_by_supplier,
             :select_dependencies_by_client,
             :select_all_packaged_elements,
             :find_subtype_of_from_generalization,
             :find_subtype_of_from_owned_attribute_type,
             :get_package_name,
             :xmi_index

      # Convenience: find extension element by XMI id (used by Drops for
      # dependency/inheritance lookups)
      def find_matched_element(xmi_id)
        xmi_index&.find_element(xmi_id)
      end
    end
  end
end
