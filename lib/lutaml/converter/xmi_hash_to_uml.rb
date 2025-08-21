module Lutaml
  module Converter
    module XmiHashToUml
      def create_uml_document(hash)
        ::Lutaml::Uml::Document.new.tap do |doc|
          doc.name = hash[:name]
          hash[:packages]&.each do |package_hash|
            pkg = create_uml_package(package_hash)
            doc.packages = [] if doc.packages.nil?
            doc.packages << pkg
          end
        end
      end

      def create_uml_package(hash) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        package = ::Lutaml::Uml::Package.new
        package.xmi_id = hash[:xmi_id]
        package.name = hash[:name]
        package.definition = hash[:definition]
        package.stereotype = hash[:stereotype]

        hash[:classes]&.each do |class_hash|
          class_obj = create_uml_class(class_hash)
          package.classes = [] if package.classes.nil?
          package.classes << class_obj
        end
        hash[:enums]&.each do |enum_hash|
          enum_obj = create_uml_enum(enum_hash)
          package.enums = [] if package.enums.nil?
          package.enums << enum_obj
        end
        hash[:data_types]&.each do |data_type_hash|
          data_type_obj = create_uml_data_type(data_type_hash)
          package.data_types = [] if package.data_types.nil?
          package.data_types << data_type_obj
        end
        hash[:diagrams]&.each do |diagram_hash|
          diagram_obj = create_uml_diagram(diagram_hash)
          package.diagrams = [] if package.diagrams.nil?
          package.diagrams << diagram_obj
        end
        hash[:packages]&.each do |package_hash|
          pkg = create_uml_package(package_hash)
          package.packages = [] if package.packages.nil?
          package.packages << pkg
        end

        package
      end

      def create_uml_class(hash) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        ::Lutaml::Uml::Class.new.tap do |klass| # rubocop:disable Metrics/BlockLength
          klass.xmi_id = hash[:xmi_id]
          klass.name = hash[:name]
          klass.type = hash[:type]
          klass.is_abstract = hash[:is_abstract]
          klass.definition = hash[:definition]
          klass.stereotype = hash[:stereotype]
          hash[:attributes]&.each do |attr_hash|
            attr = create_uml_attribute(attr_hash)
            klass.attributes = [] if klass.attributes.nil?
            klass.attributes << attr
          end
          hash[:associations]&.each do |assoc_hash|
            assoc = create_uml_association(assoc_hash)
            klass.associations = [] if klass.associations.nil?
            klass.associations << assoc
          end
          hash[:operations]&.each do |op_hash|
            op = create_uml_operation(op_hash)
            klass.operations = [] if klass.operations.nil?
            klass.operations << op
          end
          hash[:constraints]&.each do |constraint_hash|
            constraint = create_uml_constraint(constraint_hash)
            klass.constraints = [] if klass.constraints
            klass.constraints << constraint
          end
        end
      end

      def create_uml_enum(hash) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        ::Lutaml::Uml::Enum.new.tap do |enum|
          enum.xmi_id = hash[:xmi_id]
          enum.name = hash[:name]
          hash[:values]&.each do |value_hash|
            value = create_uml_value(value_hash)
            enum.values = [] if enum.values.nil?
            enum.values << value
          end
          enum.definition = hash[:definition]
          enum.stereotype = hash[:stereotype]
        end
      end

      def create_uml_data_type(hash) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        ::Lutaml::Uml::DataType.new.tap do |data_type|
          data_type.xmi_id = hash[:xmi_id]
          data_type.name = hash[:name]
          data_type.is_abstract = hash[:is_abstract]
          data_type.definition = hash[:definition]
          data_type.stereotype = hash[:stereotype]
          hash[:attributes]&.each do |attr_hash|
            attr = create_uml_attribute(attr_hash)
            data_type.attributes = [] if data_type.attributes.nil?
            data_type.attributes << attr
          end
          hash[:operations]&.each do |op_hash|
            op = create_uml_operation(op_hash)
            data_type.operations = [] if data_type.operations.nil?
            data_type.operations << op
          end
          hash[:associations]&.each do |assoc_hash|
            assoc = create_uml_association(assoc_hash)
            data_type.associations = [] if data_type.associations.nil?
            data_type.associations << assoc
          end
          hash[:constraints]&.each do |constraint_hash|
            constraint = create_uml_constraint(constraint_hash)
            data_type.constraints = [] if data_type.constraints
            data_type.constraints << constraint
          end
        end
      end

      def create_uml_diagram(hash)
        ::Lutaml::Uml::Diagram.new.tap do |diagram|
          diagram.xmi_id = hash[:xmi_id]
          diagram.name = hash[:name]
          diagram.definition = hash[:definition]
        end
      end

      def create_uml_attribute(hash) # rubocop:disable Metrics/AbcSize
        ::Lutaml::Uml::TopElementAttribute.new.tap do |attr|
          attr.id = hash[:id]
          attr.name = hash[:name]
          attr.type = hash[:type]
          attr.xmi_id = hash[:xmi_id]
          attr.is_derived = hash[:is_derived]
          attr.cardinality = create_uml_cardinality(hash[:cardinality])
          attr.definition = hash[:definition]
        end
      end

      def create_uml_cardinality(hash)
        ::Lutaml::Uml::Cardinality.new.tap do |cardinality|
          cardinality.min = hash[:min]
          cardinality.max = hash[:max]
        end
      end

      def create_uml_association(hash) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        ::Lutaml::Uml::Association.new.tap do |assoc|
          assoc.xmi_id = hash[:xmi_id]
          assoc.member_end = hash[:member_end]
          assoc.member_end_type = hash[:member_end_type]
          assoc.member_end_cardinality = create_uml_cardinality(
            hash[:member_end_cardinality],
          )
          assoc.member_end_attribute_name = hash[:member_end_attribute_name]
          assoc.member_end_xmi_id = hash[:member_end_xmi_id]
          assoc.owner_end = hash[:owner_end]
          assoc.owner_end_xmi_id = hash[:owner_end_xmi_id]
          assoc.definition = hash[:definition]
        end
      end

      def create_uml_operation(hash)
        ::Lutaml::Uml::Operation.new.tap do |op|
          op.id = hash[:id]
          op.xmi_id = hash[:xmi_id]
          op.name = hash[:name]
          op.definition = hash[:definition]
        end
      end

      def create_uml_constraint(hash)
        ::Lutaml::Uml::Constraint.new.tap do |constraint|
          constraint.name = hash[:name]
          constraint.type = hash[:type]
          constraint.weight = hash[:weight]
          constraint.status = hash[:status]
        end
      end

      def create_uml_value(hash)
        ::Lutaml::Uml::Value.new.tap do |value|
          value.name = hash[:name]
          value.type = hash[:type]
          value.definition = hash[:definition]
        end
      end
    end
  end
end
