# frozen_string_literal: true

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        # @param node_id [String]
        # @return [Array<Hash>]
        # @note xpath %(//diagrams/diagram/model[@package="#{node['xmi:id']}"])
        def serialize_model_diagrams(node_id, with_package: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          diagrams = diagram_lookup[node_id]

          diagrams.map do |diagram|
            h = {
              xmi_id: diagram.id,
              name: diagram.properties.name,
              definition: diagram.properties.documentation,
            }

            if with_package
              package_id = diagram.model.package
              h[:package_id] = package_id
              h[:package_name] = find_packaged_element_by_id(package_id)&.name
            end

            h
          end
        end

        # Lazy-built hash index for O(1) diagram lookups by package
        # @return [Hash] Mapping of package_id => [diagrams]
        def diagram_lookup
          @diagram_lookup ||= begin
            idx = Hash.new { |h, k| h[k] = [] }
            diagrams = @xmi_root_model.extension&.diagrams&.diagram || []
            diagrams.each { |d| idx[d.model.package] << d if d.model&.package }
            idx
          end
        end
      end
    end
  end
end
