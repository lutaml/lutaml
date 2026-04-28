# frozen_string_literal: true

module Lutaml
  module UmlRepository
    class Repository
      # Deprecated API methods kept for backward compatibility.
      #
      # These methods delegate to the current API but are marked for removal
      # in a future major version. Include this module to maintain backward
      # compatibility with older callers.
      module Deprecated
        # @deprecated Use {Repository#search} with types: [:class] instead
        def search_classes(query_string)
          search(query_string, types: [:class])[:classes]
        end

        # @deprecated Use {Repository#subtypes_of} instead
        def find_children(class_or_qname, recursive: false)
          subtypes_of(class_or_qname, recursive: recursive)
        end

        # @deprecated Use {Repository#associations_of} instead
        def find_associations(class_or_qname, options = {})
          associations_of(class_or_qname, options)
        end

        # @deprecated Use {Repository#diagrams_in_package} or {#all_diagrams}
        def find_diagrams(package_path)
          diagrams_in_package(package_path)
        end

        # @deprecated Use {Repository#export_to_package} instead
        def export(output_path, options = {})
          export_to_package(output_path, options)
        end
      end
    end
  end
end
