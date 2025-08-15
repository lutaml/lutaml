module Lutaml
  module Converter
    module DslToUml
      def create_uml_document(hash)
        ::Lutaml::Uml::Document.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_package(hash)
        ::Lutaml::Uml::Package.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_class(hash)
        ::Lutaml::Uml::Class.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_enum(hash)
        ::Lutaml::Uml::Enum.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_data_type(hash)
        ::Lutaml::Uml::DataType.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_diagram(hash)
        ::Lutaml::Uml::Diagram.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_attribute(hash) # rubocop:disable Metrics/AbcSize
        ::Lutaml::Uml::TopElementAttribute.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_cardinality(hash)
        ::Lutaml::Uml::Cardinality.new.tap do |cardinality|
          cardinality.min = hash[:min]
          cardinality.max = hash[:max]
        end
      end

      def create_uml_association(hash) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        ::Lutaml::Uml::Association.new.tap do |model|
          member_end_cardinality = hash.delete(:member_end_cardinality)
          if member_end_cardinality
            model.member_end_cardinality = create_uml_cardinality(
              member_end_cardinality,
            )
          end
          owner_end_cardinality = hash.delete(:owner_end_cardinality)
          if owner_end_cardinality
            model.owner_end_cardinality = create_uml_cardinality(
              owner_end_cardinality,
            )
          end

          set_uml_model(model, hash)
        end
      end

      def create_uml_operation(hash)
        ::Lutaml::Uml::Operation.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_constraint(hash)
        ::Lutaml::Uml::Constraint.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def create_uml_value(hash)
        ::Lutaml::Uml::Value.new.tap do |model|
          set_uml_model(model, hash)
        end
      end

      def set_uml_model(model, hash)
        hash = create_uml_members(model, hash)
        set_model_attribute(model, hash)
      end

      def set_model_attribute(model, hash) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        hash.each do |key, value|
          if key == :definition
            value = value.to_s.gsub(/\\}/, "}").gsub(/\\{/, "{")
              .split("\n").map(&:strip).join("\n")
          end

          if model.respond_to?("#{key}=")
            if model.class.attributes[key.to_sym].options[:collection]
              values = model.send(key.to_sym).to_a
              values << value
              model.send("#{key}=", values)
            else
              model.send("#{key}=", value)
            end
          end
        end
      end

      def create_uml_members(model, hash) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        members = hash.delete(:members)
        members.to_a.each do |member_hash|
          member_hash.each do
            create_uml_packages(model, member_hash)
            create_uml_classes(model, member_hash)
            create_uml_enums(model, member_hash)
            create_uml_data_types(model, member_hash)
            create_uml_diagrams(model, member_hash)
            create_uml_attributes(model, member_hash)
            create_uml_associations(model, member_hash)
            create_uml_operations(model, member_hash)
            create_uml_constraints(model, member_hash)
            create_uml_values(model, member_hash)
            set_model_attribute(model, member_hash)
          end
        end
        hash
      end

      def create_uml_packages(model, hash)
        packages = hash.delete(:packages)
        return [] if packages.nil?

        attr = create_uml_package(packages)
        model.packages = [] if model.packages.nil?
        model.packages << attr
        hash
      end

      def create_uml_classes(model, hash)
        classes = hash.delete(:classes)
        return [] if classes.nil?

        attr = create_uml_class(classes)
        model.classes = [] if model.classes.nil?
        model.classes << attr
        hash
      end

      def create_uml_enums(model, hash)
        enums = hash.delete(:enums)
        return [] if enums.nil?

        attr = create_uml_enum(enums)
        model.enums = [] if model.enums.nil?
        model.enums << attr
        hash
      end

      def create_uml_data_types(model, hash)
        data_types = hash.delete(:data_types)
        return [] if data_types.nil?

        attr = create_uml_data_type(data_types)
        model.data_types = [] if model.data_types.nil?
        model.data_types << attr
        hash
      end

      def create_uml_diagrams(model, hash)
        diagrams = hash.delete(:diagrams)
        return [] if diagrams.nil?

        attr = create_uml_diagram(diagrams)
        model.diagrams = [] if model.diagrams.nil?
        model.diagrams << attr
        hash
      end

      def create_uml_attributes(model, hash)
        attributes = hash.delete(:attributes)
        return [] if attributes.nil?

        attr = create_uml_attribute(attributes)
        model.attributes = [] if model.attributes.nil?
        model.attributes << attr
        hash
      end

      def create_uml_associations(model, hash)
        associations = hash.delete(:associations)
        return [] if associations.nil?

        attr = create_uml_association(associations)
        model.associations = [] if model.associations.nil?
        model.associations << attr
        hash
      end

      def create_uml_operations(model, hash)
        operations = hash.delete(:operations)
        return [] if operations.nil?

        attr = create_uml_operation(operations)
        model.operations = [] if model.operations.nil?
        model.operations << attr
        hash
      end

      def create_uml_constraints(model, hash)
        constraints = hash.delete(:constraints)
        return [] if constraints.nil?

        attr = create_uml_constraint(constraints)
        model.constraints = [] if model.constraints.nil?
        model.constraints << attr
        hash
      end

      def create_uml_values(model, hash)
        values = hash.delete(:values)
        return [] if values.nil?

        attr = create_uml_value(values)
        model.values = [] if model.values.nil?
        model.values << attr
        hash
      end
    end
  end
end
