# frozen_string_literal: true

require "lutaml/uml/parsers/dsl"

module Lutaml
  module Lml
    # Class for parsing LutaML lml into Lutaml::Lml::Document
    class Parser < Uml::Parsers::Dsl
      def create_document(hash)
        process_instances(hash)

        create_lml_document(normalize_attributes(hash))
      end

      def create_lml_document(hash)
        ::Lutaml::Lml::Document.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_instances(model, hash)
        ::Lutaml::Lml::InstanceCollection.new.tap do |collection|
          set_lml_model(collection, hash)
        end
      end

      def create_lml_package(hash)
        ::Lutaml::Lml::Package.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_class(hash)
        ::Lutaml::Lml::Class.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_enum(hash)
        ::Lutaml::Lml::Enum.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_data_type(hash)
        ::Lutaml::Lml::DataType.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_diagram(hash)
        ::Lutaml::Lml::Diagram.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_attribute(hash) # rubocop:disable Metrics/AbcSize
        ::Lutaml::Lml::TopElementAttribute.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_cardinality(hash)
        ::Lutaml::Lml::Cardinality.new.tap do |cardinality|
          cardinality.min = hash[:min]
          cardinality.max = hash[:max]
        end
      end

      def create_lml_association(hash) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        ::Lutaml::Lml::Association.new.tap do |model|
          member_end_cardinality = hash.delete(:member_end_cardinality)
          if member_end_cardinality
            model.member_end_cardinality = create_lml_cardinality(
              member_end_cardinality,
            )
          end
          owner_end_cardinality = hash.delete(:owner_end_cardinality)
          if owner_end_cardinality
            model.owner_end_cardinality = create_lml_cardinality(
              owner_end_cardinality,
            )
          end

          set_lml_model(model, hash)
        end
      end

      def create_lml_operation(hash)
        ::Lutaml::Lml::Operation.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_constraint(hash)
        ::Lutaml::Lml::Constraint.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def create_lml_value(hash)
        ::Lutaml::Lml::Value.new.tap do |model|
          set_lml_model(model, hash)
        end
      end

      def set_lml_model(model, hash)
        hash = create_lml_members(model, hash)
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

      def create_lml_members(model, hash) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        members = hash.delete(:members)
        members.to_a.each do |member_hash|
          member_hash.each do
            create_lml_instances(model, member_hash)
            create_lml_packages(model, member_hash)
            create_lml_classes(model, member_hash)
            create_lml_enums(model, member_hash)
            create_lml_data_types(model, member_hash)
            create_lml_diagrams(model, member_hash)
            create_lml_attributes(model, member_hash)
            create_lml_associations(model, member_hash)
            create_lml_operations(model, member_hash)
            create_lml_constraints(model, member_hash)
            create_lml_values(model, member_hash)
            set_model_attribute(model, member_hash)
          end
        end
        hash
      end

      def create_lml_packages(model, hash)
        packages = hash.delete(:packages)
        return [] if packages.nil?

        attr = create_lml_package(packages)
        model.packages = [] if model.packages.nil?
        model.packages << attr
        hash
      end

      def create_lml_classes(model, hash)
        classes = hash.delete(:classes)
        return [] if classes.nil?

        attr = create_lml_class(classes)
        model.classes = [] if model.classes.nil?
        model.classes << attr
        hash
      end

      def create_lml_enums(model, hash)
        enums = hash.delete(:enums)
        return [] if enums.nil?

        attr = create_lml_enum(enums)
        model.enums = [] if model.enums.nil?
        model.enums << attr
        hash
      end

      def create_lml_data_types(model, hash)
        data_types = hash.delete(:data_types)
        return [] if data_types.nil?

        attr = create_lml_data_type(data_types)
        model.data_types = [] if model.data_types.nil?
        model.data_types << attr
        hash
      end

      def create_lml_diagrams(model, hash)
        diagrams = hash.delete(:diagrams)
        return [] if diagrams.nil?

        attr = create_lml_diagram(diagrams)
        model.diagrams = [] if model.diagrams.nil?
        model.diagrams << attr
        hash
      end

      def create_lml_attributes(model, hash)
        attributes = hash.delete(:attributes)
        return [] if attributes.nil?

        attr = create_lml_attribute(attributes)
        model.attributes = [] if model.attributes.nil?
        model.attributes << attr
        hash
      end

      def create_lml_associations(model, hash)
        associations = hash.delete(:associations)
        return [] if associations.nil?

        attr = create_lml_association(associations)
        model.associations = [] if model.associations.nil?
        model.associations << attr
        hash
      end

      def create_lml_operations(model, hash)
        operations = hash.delete(:operations)
        return [] if operations.nil?

        attr = create_lml_operation(operations)
        model.operations = [] if model.operations.nil?
        model.operations << attr
        hash
      end

      def create_lml_constraints(model, hash)
        constraints = hash.delete(:constraints)
        return [] if constraints.nil?

        attr = create_lml_constraint(constraints)
        model.constraints = [] if model.constraints.nil?
        model.constraints << attr
        hash
      end

      def create_lml_values(model, hash)
        values = hash.delete(:values)
        return [] if values.nil?

        attr = create_lml_value(values)
        model.values = [] if model.values.nil?
        model.values << attr
        hash
      end

      def process_instances(hash)
        if hash.key?(:instances)
          complete_hash = {}
          hash[:instances].each do |value|
            next unless value.is_a?(Hash)

            if value.key?(:instance)
              complete_hash[:instances] ||= []
              complete_hash[:instances] << value[:instance]
            end

            complete_hash.merge!(value)
          end
          hash[:instances] = complete_hash
        end
      end

      def normalize_attributes(obj)
        case obj
        when Array
          obj.map { |item| normalize_attributes(item) }
        when Hash
          obj.transform_values do |v|
            if obj.keys.include?(:attributes) && v.is_a?(Array) && v.all? { |e| e.is_a?(Hash) && e.keys.size == 1 }
              # Merge array of single-key hashes into one hash
              v.reduce({}, :merge)
            else
              normalize_attributes(v)
            end
          end
        else
          obj
        end
      end
    end
  end
end
