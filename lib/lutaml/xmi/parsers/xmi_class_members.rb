# frozen_string_literal: true

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        # Class member (attribute, operation, constraint) helpers
        # used by XmiLookupService and Pipeline C (XmiToUml)

        # @param klass_id [String]
        # @return [Lutaml::Model::Serializable]
        # @note xpath %(//element[@xmi:idref="#{klass_id}"])
        def fetch_element(klass_id)
          xmi_index.find_element(klass_id)
        end

        def loopup_assoc_def(association)
          connector = fetch_connector(association)
          connector&.documentation&.value
        end

        # @param xmi_id [String]
        # @return [String]
        def get_ns_by_xmi_id(xmi_id)
          return unless xmi_id

          p = find_packaged_element_by_id(xmi_id)
          return unless p

          find_upper_level_packaged_element(p.id)&.name
        end

        # @param min [String]
        # @param max [String]
        # @return [Hash]
        def cardinality_min_max_value(min, max)
          {
            min: min,
            max: max,
          }
        end
      end
    end
  end
end
