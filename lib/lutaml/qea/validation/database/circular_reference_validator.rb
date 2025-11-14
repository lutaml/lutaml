# frozen_string_literal: true

require_relative "../base_validator"

module Lutaml
  module Qea
    module Validation
      # Detects circular dependencies and references
      class CircularReferenceValidator < BaseValidator
        def validate
          detect_circular_packages
          detect_circular_generalizations
        end

        private

        def detect_circular_packages
          packages.each do |package|
            next if package.root?

            visited = Set.new([package.package_id])
            current_id = package.parent_id

            while current_id && !current_id.zero?
              if visited.include?(current_id)
                result.add_error(
                  category: :circular_reference,
                  entity_type: :package,
                  entity_id: package.package_id.to_s,
                  entity_name: package.name,
                  field: "parent_id",
                  message: "Circular package hierarchy: " \
                           "#{visited.to_a.join(' -> ')} -> #{current_id}",
                )
                break
              end

              visited << current_id
              parent = packages.find { |p| p.package_id == current_id }
              break unless parent

              current_id = parent.parent_id
            end
          end
        end

        def detect_circular_generalizations
          # Build generalization graph
          generalizations = connectors.select(&:generalization?)

          # For each class, check if it has circular inheritance
          objects.each do |obj|
            visited = Set.new([obj.ea_object_id])
            queue = [obj.ea_object_id]

            while queue.any?
              current_id = queue.shift

              # Find all parents of current object
              parents = generalizations
                .select { |g| g.start_object_id == current_id }
                .map(&:end_object_id)

              parents.each do |parent_id|
                if visited.include?(parent_id)
                  # Found circular inheritance
                  result.add_error(
                    category: :circular_reference,
                    entity_type: :generalization,
                    entity_id: obj.ea_object_id.to_s,
                    entity_name: obj.name,
                    message: "Circular inheritance detected: " \
                             "#{format_inheritance_path(visited, parent_id)}",
                  )
                  next
                end

                visited << parent_id
                queue << parent_id
              end
            end
          end
        end

        def format_inheritance_path(visited_ids, circular_id)
          path = visited_ids.map do |id|
            obj = objects.find { |o| o.ea_object_id == id }
            obj&.name || id.to_s
          end

          circular_obj = objects.find { |o| o.ea_object_id == circular_id }
          path << (circular_obj&.name || circular_id.to_s)

          path.join(" -> ")
        end

        def packages
          @packages ||= context[:db_packages] || []
        end

        def objects
          @objects ||= context[:db_objects] || []
        end

        def connectors
          @connectors ||= context[:connectors] || []
        end
      end
    end
  end
end
