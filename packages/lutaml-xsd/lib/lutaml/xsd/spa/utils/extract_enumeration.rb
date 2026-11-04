# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Utils
        module ExtractEnumeration
          # Extract enumeration default value from an attribute
          # with inline simpleType
          #
          # @param attr [Attribute] Attribute object
          # @return [String, nil] Formatted enumeration default string
          def extract_enumeration_default(attr)
            unless attr.simple_type
              return [nil,
                      nil]
            end

            st = attr.simple_type
            if st.restriction
              # <xsd:simpleType>
              #   <xsd:restriction base="xsd:token">
              #     <xsd:enumeration value="A"/>
              #     <xsd:enumeration value="B"/>
              #   </xsd:restriction>
              # </xsd:simpleType>
              restriction = st.restriction
              if restriction.enumeration
                enum_str = extract_enumeration_values(restriction.enumeration)
                return [enum_str, restriction.base]
              end
            elsif st.union
              # <xsd:simpleType>
              #   <xsd:union memberTypes="xsd:token">
              #     <xsd:simpleType>
              #       <xsd:restriction base="xsd:token">
              #         <xsd:enumeration value="A"/>
              #         <xsd:enumeration value="B"/>
              #       </xsd:restriction>
              #     </xsd:simpleType>
              #   </xsd:union>
              # </xsd:simpleType>
              union = st.union
              union_type_str = union.member_types.to_s

              if union.simple_type
                union_sub_type = union.simple_type.first
                if union_sub_type.restriction
                  union_restriction = union_sub_type.restriction
                  if union_restriction.enumeration
                    enum_val_str = extract_enumeration_values(union_restriction
                      .enumeration)

                    enum_type_str = union_restriction.base
                    enum_str = "union of: [ #{union_type_str}, " \
                               "[ #{union_restriction.base} " \
                               "(#{enum_val_str}) ] ]"

                    return [enum_str, enum_type_str]
                  end
                end
              end
            end

            [nil, nil]
          end

          # Extract enumeration values in string
          #
          # @param attr [Enumeration] Enumeration object
          # @return [String]
          def extract_enumeration_values(enumeration)
            values = enumeration.map { |e| "'#{e.value}'" }
            "value comes from list: #{values.join('|')}"
          end
        end
      end
    end
  end
end
