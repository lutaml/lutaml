# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # EA Cross-Reference Model
      #
      # Represents a row from the t_xref table. Cross-references store
      # supplementary metadata for UML elements including stereotypes,
      # custom properties, and diagram properties. These enhance existing
      # elements but are not standalone UML elements.
      #
      # The Description field contains structured data in EA's proprietary
      # format, such as:
      # - Stereotypes: @STEREO;Name=...;FQName=...;@ENDSTEREO;
      # - Custom Properties: @PROP=@NAME=...@ENDNAME;@TYPE=...@ENDTYPE;...
      # - Diagram Settings: DGS=On=0:CNT=8:W=120:H=40:...
      #
      # @example Stereotype cross-reference
      #   xref = EaXref.new(
      #     xref_id: "{ABC-123}",
      #     name: "Stereotypes",
      #     type: "element property",
      #     client: "{DEF-456}",
      #     description: "@STEREO;Name=FeatureType;...@ENDSTEREO;"
      #   )
      #
      # @example Custom property cross-reference
      #   xref = EaXref.new(
      #     name: "CustomProperties",
      #     type: "element property",
      #     description: "@PROP=@NAME=isID@ENDNAME;@TYPE=Boolean@ENDTYPE;..."
      #   )
      class EaXref < BaseModel
        # @!attribute xrefid
        #   @return [String] Unique cross-reference identifier (GUID)
        attribute :xrefid, :string

        # @!attribute name
        #   @return [String, nil] Cross-reference category
        #     (e.g., "Stereotypes", "CustomProperties")
        attribute :name, :string

        # @!attribute type
        #   @return [String, nil] Type of cross-reference
        #     Values include:
        #     - "element property" (objects)
        #     - "attribute property" (attributes)
        #     - "connector property" (connectors)
        #     - "connectorSrcEnd property" (connector source ends)
        #     - "connectorDestEnd property" (connector destination ends)
        #     - "diagram properties" (diagrams)
        attribute :type, :string

        # @!attribute visibility
        #   @return [String, nil] Visibility of the cross-reference
        attribute :visibility, :string

        # @!attribute namespace
        #   @return [String, nil] Namespace for the cross-reference
        attribute :namespace, :string

        # @!attribute requirement
        #   @return [String, nil] Requirement information
        attribute :requirement, :string

        # @!attribute constraint
        #   @return [String, nil] Constraint information
        attribute :constraint, :string

        # @!attribute behavior
        #   @return [String, nil] Behavior information
        attribute :behavior, :string

        # @!attribute partition
        #   @return [String, nil] Partition information
        attribute :partition, :string

        # @!attribute description
        #   @return [String, nil] Structured metadata in EA's proprietary
        #     format. Contains the actual stereotype names, custom property
        #     values, or diagram settings.
        attribute :description, :string

        # @!attribute client
        #   @return [String, nil] GUID of the element this xref belongs to
        #     Links to Object_ID in t_object, ea_guid in t_connector,
        #     ea_guid in t_attribute, or ea_guid in t_diagram
        attribute :client, :string

        # @!attribute supplier
        #   @return [String, nil] GUID of the supplier element
        attribute :supplier, :string

        # @!attribute link
        #   @return [String, nil] Link information
        attribute :link, :string

        # Parse stereotype information from Description field
        #
        # @return [Hash, nil] Parsed stereotype data with keys:
        #   - :name (String) - Stereotype name
        #   - :fqname (String, optional) - Fully qualified name
        #   - :guid (String, optional) - Stereotype GUID
        #
        # @example
        #   xref.parse_stereotype
        #   # => {name: "FeatureType", fqname: "GML::FeatureType"}
        def parse_stereotype
          return nil unless name == "Stereotypes" && description

          result = {}
          description.scan(/(\w+)=([^;]+);/) do |key, value|
            result[key.downcase.to_sym] = value
          end
          result.empty? ? nil : result
        end

        # Parse custom property information from Description field
        #
        # @return [Hash, nil] Parsed custom property with keys:
        #   - :name (String) - Property name
        #   - :type (String) - Property type
        #   - :value (String) - Property value
        #   - :prompt (String, optional) - Prompt text
        #
        # @example
        #   xref.parse_custom_property
        #   # => {name: "isID", type: "Boolean", value: "0"}
        def parse_custom_property
          return nil unless name == "CustomProperties" && description

          result = {}
          # Parse @NAME=...@ENDNAME; format
          result[:name] = description[/@NAME=([^@]+)@ENDNAME/, 1]
          result[:type] = description[/@TYPE=([^@]+)@ENDTYPE/, 1]
          result[:value] = description[/@VALU=([^@]+)@ENDVALU/, 1]
          result[:prompt] = description[/@PRMT=([^@]+)@ENDPRMT/, 1]

          result.compact!
          result.empty? ? nil : result
        end

        # Check if this is a stereotype cross-reference
        #
        # @return [Boolean] true if this xref represents a stereotype
        def stereotype?
          name == "Stereotypes"
        end

        # Check if this is a custom property cross-reference
        #
        # @return [Boolean] true if this xref represents a custom property
        def custom_property?
          name == "CustomProperties"
        end

        # Check if this xref applies to an element (object)
        #
        # @return [Boolean] true if type is "element property"
        def element_property?
          type == "element property"
        end

        # Check if this xref applies to an attribute
        #
        # @return [Boolean] true if type is "attribute property"
        def attribute_property?
          type == "attribute property"
        end

        # Check if this xref applies to a connector
        #
        # @return [Boolean] true if type contains "connector"
        def connector_property?
          type&.include?("connector")
        end

        # Check if this xref applies to a diagram
        #
        # @return [Boolean] true if type is "diagram properties"
        def diagram_property?
          type == "diagram properties"
        end
      end
    end
  end
end
