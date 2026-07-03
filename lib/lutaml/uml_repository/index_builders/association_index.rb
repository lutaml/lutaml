# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module IndexBuilders
      module AssociationIndex
        def build_association_index
          index_document_associations
          index_class_level_associations
        end

        def index_document_associations
          @document.associations&.each do |assoc|
            next unless assoc.xmi_id

            @associations[assoc.xmi_id] = assoc
          end
        end

        def index_class_level_associations
          @qualified_names.each_value do |klass|
            next unless klassifiable?(klass) && klass.associations

            klass.associations.each do |assoc|
              next unless assoc.xmi_id

              @associations[assoc.xmi_id] ||= assoc
            end
          end
        end

        def klassifiable?(klass)
          klass.is_a?(Lutaml::Uml::Class) || klass.is_a?(Lutaml::Uml::DataType)
        end

        # Build the inheritance graph index
        #
        # Creates a hash mapping parent qualified names to arrays of
        # child qualified names:
        #   "ModelRoot::Parent" => ["ModelRoot::Child1", "ModelRoot::Child2"]
        # @api public
        def build_inheritance_graph_index
          # Process top-level classes
          if @document.classes
            process_generalizations(@document.classes,
                                    IndexBuilder::ROOT_PACKAGE_NAME)
          end

          # Process classes in packages
          traverse_packages(@document.packages,
                            parent_path: IndexBuilder::ROOT_PACKAGE_NAME) do |package, path|
            process_generalizations(package.classes, path) if package.classes
          end
        end

        # Process generalization relationships to build inheritance graph
        #
        # @param classes [Array<Lutaml::Uml::Class>] Classes to process
        # @param package_path [String] Package path for these classes
        def process_generalizations(classes, package_path)
          return unless classes

          classes.each do |klass|
            next unless klass.name

            child_qname = "#{package_path}::#{klass.name}"
            index_generalization_edge(child_qname, klass, package_path)
            index_inheritance_assoc_edges(child_qname, klass, package_path)
          end
        end

        def index_generalization_edge(child_qname, klass, package_path)
          return unless klass.generalization

          parent_name = extract_parent_name(klass.generalization)
          return unless parent_name

          parent_qname = resolve_qualified_name(parent_name, package_path)
          return unless parent_qname && child_qname != parent_qname

          (@inheritance_graph[parent_qname] ||= []) << child_qname
        end

        def index_inheritance_assoc_edges(child_qname, klass, package_path)
          return unless klass.associations

          klass.associations
            .select { |assoc| assoc.member_end_type == "inheritance" }
            .each do |assoc|
            index_inheritance_edge(child_qname, assoc,
                                   package_path)
          end
        end

        def index_inheritance_edge(child_qname, assoc, package_path)
          parent_name = resolve_parent_name_from_assoc(assoc)
          return unless parent_name

          parent_qname = resolve_qualified_name(parent_name, package_path)
          return unless parent_qname && child_qname != parent_qname

          (@inheritance_graph[parent_qname] ||= []) << child_qname
        end

        def resolve_parent_name_from_assoc(assoc)
          parent_name = assoc.member_end
          return nil unless parent_name

          parent_name = parent_name.name if parent_name.is_a?(Lutaml::Uml::Generalization)
          parent_name.is_a?(String) && !parent_name.empty? ? parent_name : nil
        end

        # Extract parent name from generalization object
        #
        # @param generalization [Lutaml::Uml::Generalization]
        # Generalization object
        # @return [String, nil] Parent class name
        def extract_parent_name(generalization)
          return nil unless generalization

          name_from_general(generalization) || generalization.name
        end

        # Resolve a class name to its qualified name
        #
        # This is a simplified resolution that checks:
        # 1. Same package
        # 2. Already qualified name in index
        #
        # @param name [String] Class name to resolve
        # @param current_package_path [String] Current package context
        # @return [String, nil] Resolved qualified name
        def name_from_general(generalization)
          parent = generalization.general
          return nil unless parent

          parent.is_a?(String) ? parent : parent.name
        end

        def resolve_qualified_name(name, current_package_path)
          # If name contains "::", it might already be qualified
          return name if @qualified_names.key?(name)

          # Try in current package
          local_qname = "#{current_package_path}::#{name}"
          return local_qname if @qualified_names.key?(local_qname)

          # O(1) lookup using reverse index instead of O(n) scan
          candidates = @simple_name_to_qnames[name]
          candidates&.first
        end
      end
    end
  end
end
