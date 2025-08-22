# frozen_string_literal: true

require "lutaml/uml/parsers/dsl"

module Lutaml
  module Lml
    # Class for parsing LutaML lml into Lutaml::Lml::Document
    class Parser < Uml::Parsers::Dsl
      def create_document(hash)
        process_data(hash)

        create_lml_document(hash)
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
              value.is_a?(Array) ? values.concat(value) : values << value
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

      def process_data(obj)
        case obj
        when Array
          obj = obj.map { |item| process_data(item) }
        when Hash
          obj.each do |key, value|
            case key
            when :requires
              obj[key] = process_requires(value)
            when :instances
              obj[key] = process_instances(value)
            when :instance
              obj[key] = process_instance(value)
            when :attributes
              obj[key] = process_attributes(value)
            else
              obj[key] = process_data(value)
            end
          end
        else
          obj
        end
      end

      def process_requires(obj)
        obj.map { |req| process_value(req).last }
      end

      def process_instances(obj)
        return [] unless obj.is_a?(Array)

        obj = obj.each_with_object({}) do |instance, acc|
          acc[:instances] ||= []
          if instance.key?(:instance)
            acc[:instances] << process_instance(instance[:instance])
          elsif instance.key?(:collections)
            acc[:collections] = process_collections(instance[:collections])
          elsif instance.key?(:imports)
            acc[:imports] = process_imports(instance[:imports])
          elsif instance.key?(:exports)
            acc[:exports] = process_exports(instance[:exports])
          end
        end
      end

      def process_instance(hash)
        hash = hash.each_with_object({}) do |(key, value), result|
          case key
          when :instance_type
            result[:type] = process_value(value).last
          when :instance
            result[:instance] = process_instance(value)
          when :attributes
            result[:attributes] = process_attributes(value)
          when :template
            result[:template] = process_attributes(value[:attributes])
          else
            result[key] = process_value(value).last
          end
        end

        Instance.new(hash)
      end

      def process_attributes(obj)
        case obj
        when Array
          if obj.all? { |e| e.is_a?(Hash) && e.keys.size == 1 }
            hash = {}
            obj = obj.each do |item|
              hash[:properties] ||= []
              if item.key?(:properties)
                hash[:properties] << process_attributes(item[:properties])
              else
                hash.merge!(process_attributes(item))
              end
            end
            hash
          else
            obj.map { |item| process_attributes(item) }
          end
        when Hash
          obj[:name] = obj.delete(:key) if obj.key?(:key)
          obj[:name], obj[:value] = ["Comment", process_value(obj.delete(:comments)).last] if obj.key?(:comments)
          obj[:type], obj[:value] = process_value(obj[:value]) if obj.key?(:value)
          obj[:extended] = !!obj.delete(:add) if obj.key?(:add)

          obj[:attributes] = process_attributes(obj[:attributes]) if obj.key?(:attributes)
          obj[:properties] = process_attributes(obj[:properties]) if obj.key?(:properties)

          obj
        end
      end

      def process_collections(obj)
        obj.each_with_object({}) do |(key, value), result|
          result[key] = process_value(value).last
        end
      end

      def process_imports(obj)
        obj.map do |export|
          export.each_with_object({}) do |(key, value), result|
            if key == :attributes
              result[key] = process_attributes(value)
            else
              result[key] = process_value(value).last
            end
          end
        end
      end

      def process_exports(obj)
        obj.map do |export|
          export.each_with_object({}) do |(key, value), result|
            if key == :attributes
              result[key] = process_attributes(value)
            else
              result[key] = process_value(value).last
            end
          end
        end
      end

      def process_value(value)
        return [] if value.nil?

        if value.is_a?(Hash) && value.key?(:instance)
          ["Instance", process_instance(value[:instance])]
        elsif value.is_a?(Hash) && value.key?(:list)
          ["Array", value[:list].map { |item| process_value(item).last }]
        elsif value.is_a?(Hash) && value.key?(:string)
          ["String", value[:string]]
        elsif value.is_a?(Hash) && value.key?(:boolean)
          ["Boolean", value[:boolean] == "true"]
        elsif value.is_a?(Hash) && value.key?(:key_value_map)
          hv = value[:key_value_map].each_with_object({}) do |kv, h|
            key, value = kv.values_at(:key, :value)
            h[key.to_sym] = process_value(value).last
          end
          ["Hash", hv]
        elsif value.is_a?(Hash) && value.key?(:number)
          ["Number", value[:number].to_i]
        elsif value.is_a?(Hash) && value.key?(:condition)
          process_value(value[:condition])
        elsif value.is_a?(Hash) && value.key?(:require)
          process_value(value[:require])
        elsif value.is_a?(Array)
          ["Array", value.map { |item| process_value(item).last }]
        else
          [value.class.to_s, value]
        end
      end
    end
  end
end
