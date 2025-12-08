# frozen_string_literal: true

require_relative "base_transformer"
require_relative "attribute_transformer"
require_relative "operation_transformer"
require_relative "constraint_transformer"
require_relative "tagged_value_transformer"
require_relative "object_property_transformer"
require_relative "generalization_transformer"
require_relative "association_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA objects (Class type) to UML classes
      class ClassTransformer < BaseTransformer
        # Transform EA object to UML class
        # @param ea_object [EaObject] EA object model
        # @return [Lutaml::Uml::Class] UML class
        def transform(ea_object)
          return nil if ea_object.nil?

          # Allow Class, Interface, and Text objects that appear on diagrams
          is_class_type = ea_object.uml_class? || ea_object.interface?
          is_text_class = ea_object.object_type == 'Text'
          return nil unless is_class_type || is_text_class

          Lutaml::Uml::Class.new.tap do |klass|
            # Map basic properties
            klass.name = ea_object.name
            klass.xmi_id = normalize_guid_to_xmi_format(ea_object.ea_guid, "EAID")
            klass.is_abstract = ea_object.abstract?
            klass.type = is_text_class ? "Class" : "Class"  # Text objects exported as Class in XMI
            klass.visibility = map_visibility(ea_object.visibility)

            # Map stereotype - return string if single, array if multiple
            stereotypes = []
            if ea_object.stereotype && !ea_object.stereotype.empty?
              stereotypes << ea_object.stereotype
            end

            # Check t_xref for additional stereotypes (only if not already added)
            xref_stereotype = load_stereotype_from_xref(ea_object.ea_guid)
            if xref_stereotype && !stereotypes.include?(xref_stereotype)
              stereotypes << xref_stereotype
            end

            # Return string if single stereotype, array if multiple, nil if none
            unless stereotypes.empty?
              klass.stereotype = stereotypes.size == 1 ? stereotypes.first : stereotypes
            end

            # Add "interface" stereotype if it's an interface
            if ea_object.interface?
              if klass.stereotype.nil?
                klass.stereotype = "interface"
              elsif klass.stereotype.is_a?(String)
                klass.stereotype = [klass.stereotype, "interface"].uniq
              elsif klass.stereotype.is_a?(Array)
                klass.stereotype << "interface" unless klass.stereotype.include?("interface")
              end
            end

            # Map definition/notes
            klass.definition = normalize_line_endings(ea_object.note) unless
              ea_object.note.nil? || ea_object.note.empty?

            # Load and transform attributes
            klass.attributes = load_attributes(ea_object.ea_object_id)

            # Load and transform operations
            klass.operations = load_operations(ea_object.ea_object_id)

            # Load and transform constraints
            klass.constraints = load_constraints(ea_object.ea_object_id)

            # Load and transform tagged values
            klass.tagged_values = load_tagged_values(ea_object.ea_guid)

            # Load and transform object properties (as additional tagged values)
            klass.tagged_values.concat(load_object_properties(ea_object.ea_object_id))

            # Load generalization (inheritance)
            klass.generalization = load_generalization(ea_object.ea_object_id)

            # Load association generalizations
            klass.association_generalization = load_association_generalizations(ea_object.ea_object_id)

            # Load associations for this class
            klass.associations = load_class_associations(ea_object.ea_object_id, ea_object.ea_guid)
          end
        end

        private

        # Load and transform attributes for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::TopElementAttribute>] UML attributes
        def load_attributes(object_id)
          return [] if object_id.nil?

          # Query t_attribute table
          query = "SELECT * FROM t_attribute WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          ea_attributes = rows.map do |row|
            Models::EaAttribute.from_db_row(row)
          end

          # Transform to UML attributes
          attribute_transformer = AttributeTransformer.new(database)
          attribute_transformer.transform_collection(ea_attributes)
        end

        # Load and transform operations for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Operation>] UML operations
        def load_operations(object_id)
          return [] if object_id.nil?

          # Query t_operation table
          query = "SELECT * FROM t_operation WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          ea_operations = rows.map do |row|
            Models::EaOperation.from_db_row(row)
          end

          # Transform to UML operations
          operation_transformer = OperationTransformer.new(database)
          operation_transformer.transform_collection(ea_operations)
        end

        # Load and transform constraints for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Constraint>] UML constraints
        def load_constraints(object_id)
          return [] if object_id.nil?
          return [] unless database.object_constraints

          # Filter constraints for this object from the in-memory collection
          ea_constraints = database.object_constraints.select do |c|
            c.ea_object_id == object_id
          end

          # Transform to UML constraints
          constraint_transformer = ConstraintTransformer.new(database)
          constraint_transformer.transform_collection(ea_constraints)
        end

        # Load and transform tagged values for a class
        # @param ea_guid [String] Element GUID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_tagged_values(ea_guid)
          return [] if ea_guid.nil?
          return [] unless database.tagged_values

          # Filter tagged values for this element from the in-memory collection
          ea_tags = database.tagged_values.select do |tag|
            tag.element_id == ea_guid
          end

          # Transform to UML tagged values
          tag_transformer = TaggedValueTransformer.new(database)
          tag_transformer.transform_collection(ea_tags)
        end

        # Load and transform object properties for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_object_properties(object_id)
          return [] if object_id.nil?
          return [] unless database.object_properties

          # Filter object properties for this object from the in-memory
          # collection
          ea_props = database.object_properties.select do |prop|
            prop.ea_object_id == object_id
          end

          # Transform to UML tagged values
          prop_transformer = ObjectPropertyTransformer.new(database)
          prop_transformer.transform_collection(ea_props)
        end

        # Load stereotype from t_xref table
        # @param ea_guid [String] Element GUID
        # @return [String, nil] Stereotype value
        def load_stereotype_from_xref(ea_guid)
          return nil if ea_guid.nil?
          return nil unless database.xrefs

          # Find stereotype xref from the in-memory collection
          xref = database.xrefs.find do |x|
            x.client == ea_guid && x.name == 'Stereotypes' && x.type == 'element property'
          end

          return nil unless xref

          # Parse stereotype from Description field
          # Format: @STEREO;Name=FeatureType;FQName=...;@ENDSTEREO;
          description = xref.description
          return nil if description.nil? || description.empty?

          # Extract the Name value from the @STEREO format
          if description =~ /@STEREO;Name=([^;]+);/
            return $1
          end

          nil
        end

        # Load generalization for a class
        # @param object_id [Integer] Object ID
        # @param visited [Set] Set of visited object IDs to prevent circular references
        # @param is_leaf [Boolean] Whether this is the leaf class (not a parent in recursion)
        # @return [Lutaml::Uml::Generalization, nil] UML generalization or nil
        def load_generalization(object_id, visited = Set.new, is_leaf = true)
          return nil if object_id.nil?

          # Detect circular reference
          if visited.include?(object_id)
            warn "Circular inheritance detected for object_id #{object_id}, stopping recursion"
            return nil
          end

          # Add current object to visited set
          visited = visited.dup.add(object_id)

          # 1. Load CURRENT object
          current_obj = find_object_by_id(object_id)
          return nil unless current_obj

          # 2. Find generalization connector where this class is the subtype
          query = "SELECT * FROM t_connector WHERE Start_Object_ID = ? AND Connector_Type = 'Generalization' LIMIT 1"
          rows = database.connection.execute(query, object_id)

          # 3. Create generalization object for current class
          # Even if no parent exists, we need a Generalization representing this class
          if rows.empty?
            # No parent - create terminal generalization
            gen_transformer = GeneralizationTransformer.new(database)
            generalization = gen_transformer.transform(nil, current_obj)
            return nil unless generalization
          else
            # Has parent - create generalization with parent connector
            ea_connector = Models::EaConnector.from_db_row(rows.first)
            gen_transformer = GeneralizationTransformer.new(database)
            generalization = gen_transformer.transform(ea_connector, current_obj)
            return nil unless generalization
          end

          # 4. Load CURRENT object attributes and convert to GeneralAttribute
          current_attrs = load_attributes(object_id)
          general_attrs = convert_to_general_attributes(current_attrs)

          # Set gen_name and name_ns on general_attributes (matches current class context)
          upper_klass = generalization.general_upper_klass
          gen_name = generalization.general_name
          general_attrs.each do |attr|
            attr.gen_name = gen_name
            # Determine name_ns based on type_ns (same logic as transform_general_attributes)
            name_ns = case attr.type_ns
                      when "core", "gml"
                        upper_klass
                      else
                        attr.type_ns
                      end
            attr.name_ns = name_ns || upper_klass
          end

          generalization.general_attributes = general_attrs

          # 5. Transform attributes (set name_ns, gen_name) - creates working copies
          generalization.attributes = transform_general_attributes(generalization)

          # 6. Partition into owned_props and assoc_props
          generalization.owned_props = generalization.attributes.select { |a| !a.has_association }
          generalization.assoc_props = generalization.attributes.select(&:has_association)

          # 7. Recursively load PARENT generalization with circular reference detection
          # Pass is_leaf=false so parent doesn't populate inherited_props
          parent_object_id = ea_connector&.end_object_id
          if parent_object_id
            parent_gen = load_generalization(parent_object_id, visited, false)
            if parent_gen
              generalization.general = parent_gen
              generalization.has_general = true
            end
          end

          # 8. Collect inherited properties from ancestor chain
          # Only populate inherited_props at the LEAF level (matches XMI behavior)
          collect_inherited_properties(generalization) if is_leaf && generalization.has_general

          generalization
        end

        # Convert TopElementAttribute array to GeneralAttribute array
        # @param attributes [Array<Lutaml::Uml::TopElementAttribute>]
        # @return [Array<Lutaml::Uml::GeneralAttribute>]
        def convert_to_general_attributes(attributes)
          attributes.map do |attr|
            Lutaml::Uml::GeneralAttribute.new.tap do |gen_attr|
              gen_attr.id = attr.id
              gen_attr.name = attr.name
              gen_attr.type = attr.type
              gen_attr.xmi_id = attr.xmi_id
              gen_attr.is_derived = !!attr.is_derived
              gen_attr.cardinality = attr.cardinality
              gen_attr.definition = attr.definition
              gen_attr.association = attr.association
              gen_attr.has_association = !!attr.association
              gen_attr.type_ns = attr.type_ns
            end
          end
        end

        # Transform GeneralAttributes with context (name_ns, gen_name)
        # Similar to XMI's create_uml_attributes
        # @param generalization [Lutaml::Uml::Generalization]
        # @return [Array<Lutaml::Uml::GeneralAttribute>]
        def transform_general_attributes(generalization)
          upper_klass = generalization.general_upper_klass
          gen_name = generalization.general_name
          gen_attrs = generalization.general_attributes

          gen_attrs.map do |attr|
            # Clone to avoid mutation
            transformed = attr.dup

            # Set name_ns based on type_ns
            name_ns = case attr.type_ns
                      when "core", "gml"
                        upper_klass
                      else
                        attr.type_ns
                      end
            name_ns = upper_klass if name_ns.nil?

            transformed.name_ns = name_ns
            transformed.gen_name = gen_name
            transformed.name = "" if transformed.name.nil?

            transformed
          end
        end

        # Collect inherited properties from ancestor chain
        # Similar to XMI's loop_general_item
        # @param generalization [Lutaml::Uml::Generalization]
        # @return [void] (modifies generalization in place)
        def collect_inherited_properties(generalization)
          inherited_props = []
          inherited_assoc_props = []
          level = 0

          # Walk the general chain
          current_gen = generalization.general
          while current_gen
            # Set metadata on BOTH general_attributes and attributes (matches XMI behavior)
            # upper_klass and level are set during the inheritance walk
            [current_gen.general_attributes, current_gen.attributes].each do |attr_list|
              attr_list&.each do |attr|
                attr.upper_klass = current_gen.general_upper_klass
                attr.level = level
              end
            end

            # Process each attribute in reverse order (to show super class first after reversal)
            current_gen.attributes.reverse_each do |attr|
              # Clone attribute for inherited collection
              inherited_attr = attr.dup
              inherited_attr.upper_klass = current_gen.general_upper_klass
              inherited_attr.gen_name = current_gen.general_name
              inherited_attr.level = level

              # Partition by association
              if attr.has_association
                inherited_assoc_props << inherited_attr
              else
                inherited_props << inherited_attr
              end
            end

            # Move to next level
            level += 1
            current_gen = current_gen.general
          end

          # Reverse to show super class first
          generalization.inherited_props = inherited_props.reverse
          generalization.inherited_assoc_props = inherited_assoc_props.reverse
        end

        # Load association generalizations for a class
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::AssociationGeneralization>] UML association generalizations
        def load_association_generalizations(object_id)
          return [] if object_id.nil?

          # Query for ALL generalization connectors for this class
          query = "SELECT ea_guid, End_Object_ID FROM t_connector WHERE Start_Object_ID = ? AND Connector_Type = 'Generalization'"
          rows = database.connection.execute(query, object_id)

          rows.map do |row|
            guid = row.is_a?(Hash) ? (row['ea_guid'] || row[:ea_guid]) : row[0]
            parent_object_id = row.is_a?(Hash) ? (row['End_Object_ID'] || row[:End_Object_ID]) : row[1]

            # Find parent object to get its GUID
            parent_obj = find_object_by_id(parent_object_id)
            next unless parent_obj

            Lutaml::Uml::AssociationGeneralization.new.tap do |ag|
              ag.id = normalize_guid_to_xmi_format(guid, "EAID")
              ag.type = "uml:Generalization"
              ag.general = normalize_guid_to_xmi_format(parent_obj.ea_guid, "EAID")
            end
          end.compact
        end

        # Load associations for a class
        # Creates Association objects from navigable association ends (ownedAttributes with association markers)
        # This matches XMI behavior where current class is always the owner
        # @param object_id [Integer] Object ID
        # @param object_guid [String] Object GUID
        # @return [Array<Lutaml::Uml::Association>] UML associations
        def load_class_associations(object_id, object_guid)
          return [] if object_id.nil?

          associations = []
          normalized_owner_xmi_id = normalize_guid_to_xmi_format(object_guid, "EAID")

          # Find all association-type connectors where this class participates
          query = "SELECT * FROM t_connector WHERE (Start_Object_ID = ? OR End_Object_ID = ?) AND Connector_Type IN ('Association', 'Aggregation', 'Composition')"
          rows = database.connection.execute(query, [object_id, object_id])

          rows.each do |row|
            ea_connector = Models::EaConnector.from_db_row(row)

            # Determine which end this class is on
            is_start = ea_connector.start_object_id == object_id

            # Get role name (this is the ownedAttribute name)
            owner_end_attribute_name = is_start ? ea_connector.destrole : ea_connector.sourcerole

            # Only create association if there's a navigable role name (matches XMI ownedAttribute[@association])
            next if owner_end_attribute_name.nil? || owner_end_attribute_name.empty?

            # Get member end (the other class)
            member_obj = is_start ? find_object_by_id(ea_connector.end_object_id) : find_object_by_id(ea_connector.start_object_id)
            next unless member_obj

            # Get member end attribute name (role at the opposite end, or class name if no role)
            member_end_attribute_name = is_start ? ea_connector.sourcerole : ea_connector.destrole
            member_end_attribute_name = member_obj.name if member_end_attribute_name.nil? || member_end_attribute_name.empty?

            # Get cardinality for this end
            member_cardinality_str = is_start ? ea_connector.destcard : ea_connector.sourcecard

            # Create association from this class's perspective
            associations << Lutaml::Uml::Association.new.tap do |assoc|
              assoc.xmi_id = normalize_guid_to_xmi_format(ea_connector.ea_guid, "EAID")
              assoc.name = ea_connector.name unless ea_connector.name.nil? || ea_connector.name.empty?

              # Owner is always the current class (matches XMI)
              assoc.owner_end = find_object_by_id(object_id)&.name
              assoc.owner_end_xmi_id = normalized_owner_xmi_id
              assoc.owner_end_attribute_name = owner_end_attribute_name

              # Member is the other end
              assoc.member_end = member_obj.name
              assoc.member_end_xmi_id = normalize_guid_to_xmi_format(member_obj.ea_guid, "EAID")
              assoc.member_end_attribute_name = member_end_attribute_name

              # Set member_end_type based on connector type
              case ea_connector.connector_type
              when "Aggregation"
                assoc.member_end_type = "aggregation"
              when "Composition"
                assoc.member_end_type = "composition"
              end

              # Set cardinality
              if member_cardinality_str && !member_cardinality_str.empty?
                parsed = parse_cardinality(member_cardinality_str)
                if parsed[:min] || parsed[:max]
                  assoc.member_end_cardinality = Lutaml::Uml::Cardinality.new.tap do |card|
                    card.min = parsed[:min]
                    card.max = parsed[:max]
                  end
                end
              end

              # Note: XMI does not include connector notes in Association definition
            end
          end

          associations.compact
        end

        # Load association-based attributes (navigable association ends with role names)
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::TopElementAttribute>] Association-based attributes
        def load_association_attributes(object_id)
          return [] if object_id.nil?

          attributes = []

          # Find all association-type connectors (Association, Aggregation, Composition)
          query = "SELECT * FROM t_connector WHERE (Start_Object_ID = ? OR End_Object_ID = ?) AND Connector_Type IN ('Association', 'Aggregation', 'Composition')"
          rows = database.connection.execute(query, [object_id, object_id])

          rows.each do |row|
            ea_connector = Models::EaConnector.from_db_row(row)

            # Check if this object is the source (owner) or target (member)
            if ea_connector.start_object_id == object_id
              # This class is the source - check for dest role
              next if ea_connector.destrole.nil? || ea_connector.destrole.empty?

              target_obj = find_object_by_id(ea_connector.end_object_id)
              next unless target_obj

              attributes << create_association_attribute(
                name: ea_connector.destrole,
                type: target_obj.name,
                type_xmi_id: target_obj.ea_guid,
                association_xmi_id: ea_connector.ea_guid,
                cardinality: ea_connector.destcard
              )
            elsif ea_connector.end_object_id == object_id
              # This class is the target - check for source role
              next if ea_connector.sourcerole.nil? || ea_connector.sourcerole.empty?

              source_obj = find_object_by_id(ea_connector.start_object_id)
              next unless source_obj

              attributes << create_association_attribute(
                name: ea_connector.sourcerole,
                type: source_obj.name,
                type_xmi_id: source_obj.ea_guid,
                association_xmi_id: ea_connector.ea_guid,
                cardinality: ea_connector.sourcecard
              )
            end
          end

          attributes.compact
        end

        # Create an attribute from association end
        # @param name [String] Attribute name (role name)
        # @param type [String] Attribute type (class name)
        # @param type_xmi_id [String] Type XMI ID
        # @param association_xmi_id [String] Association XMI ID
        # @param cardinality [String] Cardinality string
        # @return [Lutaml::Uml::TopElementAttribute] Created attribute
        def create_association_attribute(name:, type:, type_xmi_id:, association_xmi_id:, cardinality:)
          Lutaml::Uml::TopElementAttribute.new.tap do |attr|
            attr.name = name
            attr.type = type
            attr.xmi_id = normalize_guid_to_xmi_format(type_xmi_id, "EAID")
            attr.association = normalize_guid_to_xmi_format(association_xmi_id, "EAID")

            # Map cardinality if present
            if cardinality && !cardinality.empty?
              parsed = parse_cardinality(cardinality)
              if parsed[:min] || parsed[:max]
                attr.cardinality = Lutaml::Uml::Cardinality.new.tap do |card|
                  card.min = parsed[:min]
                  card.max = parsed[:max]
                end
              end
            end
          end
        end

        # Find object by ID
        # @param object_id [Integer] Object ID
        # @return [Models::EaObject, nil] EA object or nil
        def find_object_by_id(object_id)
          return nil if object_id.nil?

          query = "SELECT * FROM t_object WHERE Object_ID = ?"
          rows = database.connection.execute(query, [object_id])
          return nil if rows.empty?

          Models::EaObject.from_db_row(rows.first)
        end
      end
    end
  end
end
