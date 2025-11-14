# frozen_string_literal: true

module Lutaml
  module Qea
    module Factory
      # Resolves references between EA and UML elements
      # Maps EA GUIDs to UML xmi_ids and maintains object relationships
      class ReferenceResolver
        # Initialize empty resolver
        def initialize
          @guid_to_element = {}
          @object_id_to_name = {}
        end

        # Register EA GUID to UML element mapping
        # @param ea_guid [String] EA GUID
        # @param uml_element [Object] UML element with xmi_id
        # @return [void]
        def register(ea_guid, uml_element)
          return if ea_guid.nil? || uml_element.nil?

          @guid_to_element[normalize_guid(ea_guid)] = uml_element
        end

        # Register object ID to name mapping
        # @param object_id [Integer] EA object ID
        # @param name [String] Object name
        # @return [void]
        def register_object_name(object_id, name)
          return if object_id.nil?

          @object_id_to_name[object_id] = name
        end

        # Resolve EA GUID to UML element
        # @param ea_guid [String] EA GUID
        # @return [Object, nil] UML element or nil if not found
        def resolve(ea_guid)
          return nil if ea_guid.nil?

          @guid_to_element[normalize_guid(ea_guid)]
        end

        # Get object name by object ID
        # @param object_id [Integer] EA object ID
        # @return [String, nil] Object name or nil if not found
        def resolve_object_name(object_id)
          return nil if object_id.nil?

          @object_id_to_name[object_id]
        end

        # Get UML xmi_id by EA GUID
        # @param ea_guid [String] EA GUID
        # @return [String, nil] xmi_id or nil if not found
        def resolve_xmi_id(ea_guid)
          element = resolve(ea_guid)
          element&.xmi_id
        end

        # Check if GUID is registered
        # @param ea_guid [String] EA GUID
        # @return [Boolean] True if registered
        def registered?(ea_guid)
          return false if ea_guid.nil?

          @guid_to_element.key?(normalize_guid(ea_guid))
        end

        # Clear all mappings
        # @return [void]
        def clear
          @guid_to_element.clear
          @object_id_to_name.clear
        end

        # Get statistics
        # @return [Hash] Statistics about registered elements
        def stats
          {
            total_elements: @guid_to_element.size,
            total_objects: @object_id_to_name.size,
          }
        end

        private

        # Normalize GUID format (remove braces, upcase)
        # @param guid [String] GUID string
        # @return [String] Normalized GUID
        def normalize_guid(guid)
          return guid if guid.nil?

          guid.to_s.gsub(/[{}]/, "").upcase
        end
      end
    end
  end
end
