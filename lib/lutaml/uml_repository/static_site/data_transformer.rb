# frozen_string_literal: true

require_relative "id_generator"

module Lutaml
  module UmlRepository
    module StaticSite
      # Transforms a UmlRepository into a normalized JSON data structure
      # optimized for client-side navigation and search.
      #
      # The output follows a normalized structure with:
      # - Flat maps for packages, classes, attributes, associations
      # - References by stable IDs
      # - Hierarchical package tree for navigation
      #
      # @example
      #   repository = UmlRepository.from_package("model.lur")
      #   transformer = DataTransformer.new(repository)
      #   json_data = transformer.transform
      class DataTransformer
        attr_reader :repository, :id_generator, :options

        # Initialize transformer
        #
        # @param repository [UmlRepository] The repository to transform
        # @param options [Hash] Transformation options
        # @option options [Boolean] :include_diagrams Include diagram information
        # @option options [Boolean] :format_definitions Format definitions as markdown
        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IDGenerator.new
          @generalization_map = build_generalization_map
        end

        # Transform repository to JSON structure
        #
        # @return [Hash] Normalized JSON data structure
        def transform
          {
            metadata: build_metadata,
            packageTree: build_package_tree,
            packages: build_packages_map,
            classes: build_classes_map,
            attributes: build_attributes_map,
            associations: build_associations_map,
            operations: build_operations_map,
            diagrams: (@options[:include_diagrams] ? build_diagrams_map : {}),
          }
        end

        private

        def default_options
          {
            include_diagrams: true,
            format_definitions: true,
            max_definition_length: nil,
          }
        end

        # Build generalization map for multiple inheritance
        def build_generalization_map
          map = Hash.new { |h, k| h[k] = [] }

          # Scan all classes for generalization relationships
          repository.classes_index.each do |klass|
            next unless klass.respond_to?(:association_generalization)
            next unless klass.association_generalization && !klass.association_generalization.empty?

            # Each class has an association_generalization array with AssociationGeneralization objects
            klass.association_generalization.each do |assoc_gen|
              # Access lutaml-model object attributes directly
              next unless assoc_gen.respond_to?(:parent_object_id)

              parent_object_id = assoc_gen.parent_object_id
              next unless parent_object_id

              # Find the parent class by object_id and get its XMI ID
              parent_class = find_class_by_object_id(parent_object_id)
              if parent_class && parent_class.xmi_id
                # Skip self-referential generalization (class can't be its own parent)
                next if parent_class.xmi_id == klass.xmi_id
                
                map[klass.xmi_id] << parent_class.xmi_id unless map[klass.xmi_id].include?(parent_class.xmi_id)
              end
            end
          end

          map
        end

        # Build metadata section
        def build_metadata
          {
            generated: Time.now.utc.iso8601,
            generator: "LutaML Static Site Generator",
            version: "1.0",
            statistics: build_statistics,
          }
        end

        # Build statistics
        def build_statistics
          {
            packages: repository.packages_index.size,
            classes: repository.classes_index.size,
            associations: repository.associations_index.size,
            attributes: count_total_attributes,
            operations: count_total_operations,
          }
        end

        def count_total_attributes
          repository.classes_index.sum do |klass|
            klass.attributes&.size || 0
          end
        end

        def count_total_operations
          repository.classes_index.sum do |klass|
            (klass.respond_to?(:operations) ? klass.operations&.size : 0) || 0
          end
        end

        # Build hierarchical package tree
        def build_package_tree
          # Get root packages from document.packages (not from index)
          root_packages = if repository.document.respond_to?(:packages) && repository.document.packages
                           repository.document.packages
                         else
                           # Fallback: find packages without parent namespace
                           repository.packages_index.select do |pkg|
                             !pkg.respond_to?(:namespace) || pkg.namespace.nil? || !pkg.namespace.is_a?(Lutaml::Uml::Package)
                           end
                         end

          if root_packages.size == 1
            build_tree_node(root_packages.first)
          else
            # Multiple roots - create virtual root
            {
              id: "root",
              name: "Model",
              path: "",
              classCount: 0,
              children: root_packages.map { |pkg| build_tree_node(pkg) },
            }
          end
        end

        def build_tree_node(package)
          pkg_id = @id_generator.package_id(package)

          # Sort child packages by name
          sorted_children = (package.packages || []).sort_by { |p| p.name || '' }

          # Sort classes by name, filtering out unnamed classes
          # This prevents unnamed classes from appearing in the tree or being counted
          sorted_classes = (package.classes || [])
                          .reject { |c| c.name.nil? || c.name.empty? }
                          .sort_by { |c| c.name }

          # Build child nodes first to get their counts
          child_nodes = sorted_children.map do |child|
            build_tree_node(child)
          end

          # Calculate total count including nested packages
          # Only counts named classes (unnamed classes are already filtered out)
          total_class_count = sorted_classes.size + child_nodes.sum { |child| child[:classCount] || 0 }

          {
            id: pkg_id,
            name: package.name,
            path: package_path(package),
            stereotypes: normalize_stereotypes(package.respond_to?(:stereotype) ? package.stereotype : nil),
            classCount: total_class_count,
            classes: sorted_classes.map { |c|
              {
                id: @id_generator.class_id(c),
                name: c.name,
                stereotypes: normalize_stereotypes(c.respond_to?(:stereotype) ? c.stereotype : nil)
              }
            },
            children: child_nodes,
          }
        end

        # Build packages map
        def build_packages_map
          packages = {}

          repository.packages_index.each do |package|
            id = @id_generator.package_id(package)
            packages[id] = serialize_package(package, id)
          end

          packages
        end

        def serialize_package(package, id)
          {
            id: id,
            xmiId: package.respond_to?(:xmi_id) ? package.xmi_id : nil,
            name: package.name,
            path: package_path(package),
            definition: format_definition(package.respond_to?(:definition) ? package.definition : nil),
            stereotypes: normalize_stereotypes(package.respond_to?(:stereotype) ? package.stereotype : nil),
            classes: (package.classes || []).map do |c|
              @id_generator.class_id(c)
            end,
            subPackages: (package.packages || []).map do |p|
              @id_generator.package_id(p)
            end,
            diagrams: package_diagrams(package).map do |d|
              @id_generator.diagram_id(d)
            end,
            parent: (package.respond_to?(:namespace) && package.namespace.is_a?(Lutaml::Uml::Package)) ? @id_generator.package_id(package.namespace) : nil,
          }
        end

        # Build classes map
        def build_classes_map
          classes = {}

          repository.classes_index.each do |klass|
            id = @id_generator.class_id(klass)
            classes[id] = serialize_class(klass, id)
          end

          classes
        end

        def serialize_class(klass, id)
          # Get associations and sort by local role
          class_associations = find_class_associations(klass)
          sorted_associations = class_associations.sort_by do |assoc_id|
            assoc = repository.associations_index.find { |a| @id_generator.association_id(a) == assoc_id }
            next '' unless assoc

            # Determine local role for this class
            if assoc.owner_end_xmi_id == klass.xmi_id
              assoc.owner_end_attribute_name || assoc.owner_end || ''
            elsif assoc.member_end_xmi_id == klass.xmi_id
              assoc.member_end_attribute_name || assoc.member_end || ''
            else
              ''
            end
          end

          {
            id: id,
            xmiId: klass.xmi_id,
            name: klass.name,
            qualifiedName: qualified_name(klass),
            type: class_type(klass),
            package: package_id_for_class(klass),
            stereotypes: normalize_stereotypes(klass.respond_to?(:stereotype) ? klass.stereotype : nil),
            definition: format_definition(klass.definition),
            attributes: (klass.attributes || []).sort_by { |a| a.name || '' }.map do |attr|
              @id_generator.attribute_id(attr, klass)
            end,
            operations: serialize_class_operations(klass),
            associations: sorted_associations,
            generalizations: find_generalizations(klass),
            specializations: find_specializations(klass),
            isAbstract: klass.respond_to?(:is_abstract) ? klass.is_abstract : false,
            literals: serialize_literals(klass),
            inheritedAttributes: compute_inherited_attributes(klass),
            inheritedAssociations: compute_inherited_associations(klass),
          }
        end

        # Build attributes map
        def build_attributes_map
          attributes = {}

          repository.classes_index.each do |klass|
            next unless klass.attributes

            klass.attributes.each do |attr|
              id = @id_generator.attribute_id(attr, klass)
              attributes[id] = serialize_attribute(attr, klass, id)
            end
          end

          attributes
        end

        def serialize_attribute(attribute, owner, id)
          {
            id: id,
            name: attribute.name,
            type: attribute.type,
            visibility: attribute.visibility,
            owner: @id_generator.class_id(owner),
            ownerName: owner.name,
            cardinality: serialize_cardinality(attribute.cardinality),
            definition: format_definition(attribute.definition),
            stereotypes: normalize_stereotypes(attribute.respond_to?(:stereotype) ? attribute.stereotype : nil),
            isStatic: attribute.respond_to?(:is_static) ? attribute.is_static : false,
            isReadOnly: attribute.respond_to?(:is_read_only) ? attribute.is_read_only : false,
            defaultValue: attribute.respond_to?(:default) ? attribute.default : nil,
          }
        end

        # Build associations map
        # Uses repository.associations_index which handles both XMI and QEA formats
        def build_associations_map
          associations = {}

          # Repository.associations_index collects from both:
          # - Document-level associations (XMI format)
          # - Class-level associations (QEA/EA format)
          repository.associations_index.each do |assoc|
            id = @id_generator.association_id(assoc)
            associations[id] = serialize_association(assoc, id)
          end

          associations
        end

        def serialize_association(association, id)
          # Association model has member_end/owner_end as strings (class names)
          # Use member_end_xmi_id, member_end_type etc for more details
          # IMPORTANT: Do NOT generate synthetic names - use actual data only
          
          # If association.name is nil, use the role name as fallback
          # In EA models, the association name is often stored in the role fields
          # IMPORTANT: Prioritize owner_end_attribute_name which has the actual role name
          assoc_name = association.name
          if assoc_name.nil? || assoc_name.empty?
            # Try owner_end_attribute_name first (this is the role from owner's perspective)
            assoc_name = association.owner_end_attribute_name
            # Fallback to member_end_attribute_name (but this often contains class name, not role)
            assoc_name = association.member_end_attribute_name if assoc_name.nil? || assoc_name.empty?
          end
          
          {
            id: id,
            xmiId: association.xmi_id,
            name: assoc_name,
            type: "Association",
            definition: format_definition(association.respond_to?(:definition) ? association.definition : nil),
            source: build_association_source(association),
            target: build_association_target(association),
          }
        end

        def build_association_source(association)
          return nil unless association.owner_end

          {
            class: association.owner_end_xmi_id,
            className: association.owner_end,
            role: association.owner_end_attribute_name,
            cardinality: serialize_cardinality(association.owner_end_cardinality),
            aggregation: association.owner_end_type,
          }
        end

        def build_association_target(association)
          return nil unless association.member_end

          {
            class: association.member_end_xmi_id,
            className: association.member_end,
            role: association.member_end_attribute_name,
            cardinality: serialize_cardinality(association.member_end_cardinality),
            aggregation: association.member_end_type,
          }
        end

        def serialize_association_end(end_obj)
          return nil unless end_obj
          return nil unless end_obj.respond_to?(:type) && end_obj.type

          # end_obj.type can be a String (class name) or a Class object
          type_value = end_obj.type

          if type_value.is_a?(String)
            # Type is a string reference (class name)
            {
              class: nil, # Can't generate ID without class object
              className: type_value,
              role: end_obj.respond_to?(:name) ? end_obj.name : nil,
              cardinality: serialize_cardinality(end_obj.respond_to?(:cardinality) ? end_obj.cardinality : nil),
              navigable: end_obj.respond_to?(:navigable?) ? end_obj.navigable? : false,
              aggregation: end_obj.respond_to?(:aggregation) ? end_obj.aggregation : nil,
              visibility: end_obj.respond_to?(:visibility) ? end_obj.visibility : nil,
            }
          else
            # Type is a class object
            {
              class: @id_generator.class_id(type_value),
              className: type_value.respond_to?(:name) ? type_value.name : type_value.to_s,
              role: end_obj.respond_to?(:name) ? end_obj.name : nil,
              cardinality: serialize_cardinality(end_obj.respond_to?(:cardinality) ? end_obj.cardinality : nil),
              navigable: end_obj.respond_to?(:navigable?) ? end_obj.navigable? : false,
              aggregation: end_obj.respond_to?(:aggregation) ? end_obj.aggregation : nil,
              visibility: end_obj.respond_to?(:visibility) ? end_obj.visibility : nil,
            }
          end
        end

        # Build operations map
        def build_operations_map
          operations = {}

          repository.classes_index.each do |klass|
            next unless klass.respond_to?(:operations) && klass.operations

            klass.operations.each do |op|
              id = @id_generator.operation_id(op, klass)
              operations[id] = serialize_operation(op, klass, id)
            end
          end

          operations
        end

        def serialize_operation(operation, owner, id)
          {
            id: id,
            name: operation.name,
            visibility: operation.visibility,
            returnType: operation.return_type,
            owner: @id_generator.class_id(owner),
            ownerName: owner.name,
            parameters: serialize_parameters(operation),
            isStatic: operation.respond_to?(:is_static) ? operation.is_static : false,
            isAbstract: operation.respond_to?(:is_abstract) ? operation.is_abstract : false,
          }
        end

        def serialize_parameters(operation)
          return [] unless operation.respond_to?(:owned_parameter) && operation.owned_parameter

          operation.owned_parameter.map do |param|
            {
              name: param.name,
              type: param.type,
              direction: param.respond_to?(:direction) ? param.direction : "in",
            }
          end
        end

        # Build diagrams map
        def build_diagrams_map
          diagrams = {}

          repository.diagrams_index.each do |diagram|
            id = @id_generator.diagram_id(diagram)
            diagrams[id] = serialize_diagram(diagram, id)
          end

          diagrams
        rescue StandardError
          # Diagrams may not be available in all repositories
          {}
        end

        def serialize_diagram(diagram, id)
          {
            id: id,
            xmiId: diagram.xmi_id,
            name: diagram.name,
            type: diagram.diagram_type,
            package: find_diagram_package(diagram),
          }
        end

        # Helper methods

        def package_path(package)
          return package.name unless package.respond_to?(:namespace) && package.namespace
          return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

          "#{package_path(package.namespace)}::#{package.name}"
        end

        def qualified_name(klass)
          path_parts = []
          current = klass

          # Walk up the namespace chain
          while current
            if current.is_a?(Lutaml::Uml::TopElement)
              path_parts.unshift(current.name)
              current = current.respond_to?(:namespace) ? current.namespace : nil
            elsif current.is_a?(Lutaml::Uml::Package)
              path_parts.unshift(current.name)
              current = current.namespace
            else
              break
            end
          end

          path_parts.join("::")
        end

        def class_type(klass)
          klass.class.name.split("::").last
        end

        def package_id_for_class(klass)
          ns = klass.respond_to?(:namespace) ? klass.namespace : nil
          return nil unless ns&.is_a?(Lutaml::Uml::Package)

          @id_generator.package_id(ns)
        end

        def package_diagrams(package)
          return [] unless @options[:include_diagrams]

          # Use the package's direct diagrams attribute instead of querying
          package.diagrams || []
        rescue StandardError => e
          warn "Error getting diagrams for #{package.name}: #{e.message}"
          []
        end

        def find_diagram_package(diagram)
          # Try to find which package owns this diagram
          repository.packages_index.each do |pkg|
            diagrams = package_diagrams(pkg)
            if diagrams.any? { |d| d.xmi_id == diagram.xmi_id }
              return @id_generator.package_id(pkg)
            end
          end
          nil
        rescue StandardError
          nil
        end

        def serialize_cardinality(cardinality)
          return nil unless cardinality

          {
            min: cardinality.min,
            max: cardinality.max,
          }
        end

        def format_definition(definition)
          return nil if definition.nil? || definition.empty?

          formatted = definition.strip

          # Optionally truncate
          if @options[:max_definition_length] && formatted.length > @options[:max_definition_length]
            formatted = "#{formatted[0...@options[:max_definition_length]]}..."
          end

          # Optionally format as markdown (basic)
          if @options[:format_definitions]
            formatted = format_as_markdown(formatted)
          end

          formatted
        end

        def format_as_markdown(text)
          # Basic markdown formatting
          # - Preserve line breaks
          # - Convert URLs to links
          text.gsub(%r{(https?://[^\s]+)}, '[\1](\1)')
        end

        def serialize_class_operations(klass)
          return [] unless klass.respond_to?(:operations) && klass.operations

          klass.operations.map { |op| @id_generator.operation_id(op, klass) }
        end

        def find_class_associations(klass)
          associations = repository.associations_of(klass)
          associations.map { |assoc| @id_generator.association_id(assoc) }
        rescue StandardError
          []
        end

        def find_generalizations(klass)
          # Use the pre-built generalization map for multiple inheritance
          parent_xmi_ids = @generalization_map[klass.xmi_id]

          if parent_xmi_ids && !parent_xmi_ids.empty?
            # Map each parent XMI ID to class ID
            parents = parent_xmi_ids.map do |parent_xmi_id|
              # Skip self-referential generalization
              next if parent_xmi_id == klass.xmi_id
              
              parent = find_class_by_xmi_id(parent_xmi_id)
              parent ? @id_generator.class_id(parent) : nil
            end.compact

            return parents unless parents.empty?
          end

          # Fallback: single parent via repository query
          parent = repository.supertype_of(klass)
          # Skip if parent is self (self-referential generalization)
          return [] if parent && parent.xmi_id == klass.xmi_id
          
          parent ? [@id_generator.class_id(parent)] : []
        rescue StandardError => e
          warn "Error finding generalizations for #{klass.name}: #{e.message}"
          []
        end

        def find_specializations(klass)
          children = repository.subtypes_of(klass)
          # Filter out self if somehow included
          children.reject { |child| child.xmi_id == klass.xmi_id }.map { |child| @id_generator.class_id(child) }
        rescue StandardError
          []
        end

        def serialize_literals(klass)
          return [] unless klass.is_a?(Lutaml::Uml::Enum) && klass.owned_literal

          klass.owned_literal.map do |literal|
            {
              name: literal.name,
              definition: format_definition(literal.definition),
            }
          end
        rescue StandardError
          []
        end

        def serialize_generalization(klass, visited = Set.new)
          return nil unless klass.respond_to?(:generalization) && klass.generalization
          return nil if visited.include?(klass.xmi_id)  # Prevent infinite loops

          visited.add(klass.xmi_id)
          gen = klass.generalization

          {
            generalId: gen.general_id,
            generalName: gen.general_name,
            generalUpperKlass: gen.respond_to?(:general_upper_klass) ? gen.general_upper_klass : nil,
            hasGeneral: gen.respond_to?(:has_general) ? gen.has_general : false,
            name: gen.name,
            type: gen.type,
            definition: format_definition(gen.definition),
            stereotype: gen.respond_to?(:stereotype) ? gen.stereotype : nil,
            ownedProps: (gen.respond_to?(:owned_props) ? gen.owned_props : []).map { |attr| serialize_general_attribute(attr) },
            assocProps: (gen.respond_to?(:assoc_props) ? gen.assoc_props : []).map { |attr| serialize_general_attribute(attr) },
            inheritedProps: (gen.respond_to?(:inherited_props) ? gen.inherited_props : []).map { |attr| serialize_general_attribute(attr) },
            inheritedAssocProps: (gen.respond_to?(:inherited_assoc_props) ? gen.inherited_assoc_props : []).map { |attr| serialize_general_attribute(attr) },
          }
        rescue StandardError => e
          warn "Error serializing generalization: #{e.message}"
          nil
        end

        def serialize_general_attribute(attr)
          return nil unless attr

          {
            name: attr.name,
            type: attr.type,
            cardinality: serialize_cardinality(attr.cardinality),
            definition: format_definition(attr.definition),
            upperKlass: attr.respond_to?(:upper_klass) ? attr.upper_klass : nil,
            nameNs: attr.respond_to?(:name_ns) ? attr.name_ns : nil,
            typeNs: attr.respond_to?(:type_ns) ? attr.type_ns : nil,
          }
        end

        def find_generalization(parent_id)
          parent = find_class_by_xmi_id(parent_id)
          return nil unless parent

          # Recursively find all ancestors
          ancestors = find_all_ancestors(parent, []) || []
          ancestors
        end

        def find_all_ancestors(klass, ancestors = [])
          return ancestors if klass.nil?

          unless ancestors.include?(klass.xmi_id)
            ancestors << klass.xmi_id
            find_all_ancestors(klass.generalization&.general_class, ancestors) if klass.generalization&.general_classierarchy
          end
          ancestors
        end

        # Compute inherited attributes from generalization chain
        def compute_inherited_attributes(klass, visited = Set.new)
          return [] unless klass.respond_to?(:generalization) && klass.generalization
          return [] if visited.include?(klass.xmi_id)  # Prevent infinite loops

          visited.add(klass.xmi_id)
          inherited = []
          current_gen = klass.generalization
          parent_order = 0

          while current_gen
            parent_class = find_class_by_xmi_id(current_gen.general_id)
            break unless parent_class
            break if visited.include?(parent_class.xmi_id)  # Prevent cycles

            visited.add(parent_class.xmi_id)

            if parent_class.attributes
              # Sort attributes by name within this parent
              sorted_attrs = parent_class.attributes.sort_by { |a| a.name || '' }
              sorted_attrs.each do |attr|
                attr_id = @id_generator.attribute_id(attr, parent_class)
                inherited << {
                  attributeId: attr_id,
                  attribute: serialize_attribute(attr, parent_class, attr_id),
                  inheritedFrom: @id_generator.class_id(parent_class),
                  inheritedFromName: parent_class.name,
                  parentOrder: parent_order,  # Track hierarchy order
                }
              end
            end

            # Move to parent's parent
            parent_order += 1
            current_gen = current_gen.respond_to?(:general) ? current_gen.general : nil
          end

          # Already sorted by parent hierarchy, then by name within parent
          inherited
        rescue StandardError => e
          warn "Error computing inherited attributes: #{e.message}"
          []
        end

        # Compute inherited associations from generalization chain
        def compute_inherited_associations(klass, visited = Set.new)
          return [] unless klass.respond_to?(:generalization) && klass.generalization
          return [] if visited.include?(klass.xmi_id)  # Prevent infinite loops

          visited.add(klass.xmi_id)
          inherited = []
          current_gen = klass.generalization
          parent_order = 0

          while current_gen
            parent_class = find_class_by_xmi_id(current_gen.general_id)
            break unless parent_class
            break if visited.include?(parent_class.xmi_id)  # Prevent cycles

            visited.add(parent_class.xmi_id)

            parent_associations = find_class_associations(parent_class)

            # Get association details and determine local role from parent's perspective
            assoc_with_roles = parent_associations.map do |assoc_id|
              assoc = repository.associations_index.find { |a| @id_generator.association_id(a) == assoc_id }
              next unless assoc

              # Determine which role is the "local" one for the parent class
              # This becomes the inherited local role
              local_role = if assoc.owner_end_xmi_id == parent_class.xmi_id
                assoc.owner_end_attribute_name || assoc.owner_end || ''
              elsif assoc.member_end_xmi_id == parent_class.xmi_id
                assoc.member_end_attribute_name || assoc.member_end || ''
              else
                ''
              end

              { id: assoc_id, role: local_role }
            end.compact

            # Sort by local role within this parent
            assoc_with_roles.sort_by { |a| a[:role] }.each do |item|
              inherited << {
                associationId: item[:id],
                inheritedFrom: @id_generator.class_id(parent_class),
                inheritedFromName: parent_class.name,
                parentOrder: parent_order,
                localRole: item[:role],  # Include for template use
              }
            end

            # Move to parent's parent
            parent_order += 1
            current_gen = current_gen.respond_to?(:general) ? current_gen.general : nil
          end

          inherited
        rescue StandardError => e
          warn "Error computing inherited associations: #{e.message}"
          []
        end

        # Find class by XMI ID
        def find_class_by_xmi_id(xmi_id)
          return nil unless xmi_id
          repository.classes_index.find { |c| c.xmi_id == xmi_id }
        rescue StandardError
          nil
        end

        # Find class by object ID (EA object ID)
        def find_class_by_object_id(object_id)
          return nil unless object_id
          repository.classes_index.find { |c| c.respond_to?(:ea_object_id) && c.ea_object_id == object_id }
        rescue StandardError
          nil
        end

        # Normalize stereotype to always be an array
        # @param stereotype [String, Array, nil] Stereotype value
        # @return [Array<String>] Array of stereotypes
        def normalize_stereotypes(stereotype)
          return [] if stereotype.nil?
          return stereotype if stereotype.is_a?(Array)

          [stereotype]
        end
      end
    end
  end
end
