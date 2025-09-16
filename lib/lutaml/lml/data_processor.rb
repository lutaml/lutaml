module Lutaml
  module Lml
    module Dataprocessor
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
      end

      def process_attributes(obj)
        case obj
        when Array
          process_attributes_array(obj)
        when Hash
          process_attributes_hash(obj)
        end
      end

      def process_attributes_array(obj)
        if obj.all? { |e| e.is_a?(Hash) && e.keys.size == 1 }
          hash = {}
          obj.each do |item|
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
      end

      def process_attributes_hash(obj)
        obj[:name] = obj.delete(:key) if obj.key?(:key)
        if obj.key?(:comments)
          obj[:name], obj[:value] = ["Comment", process_value(obj.delete(:comments)).last]
        end
        obj[:type], obj[:value] = process_value(obj[:value]) if obj.key?(:value)

        if obj[:type]&.start_with?("Instance")
          obj[:instances] ||= []
          instance = obj.delete(:value)
          obj[:instances] += Array(instance)
          obj.delete(:type)
        end

        obj[:extended] = !!obj.delete(:add) if obj.key?(:add)

        obj[:attributes] = process_attributes(obj[:attributes]) if obj.key?(:attributes)
        obj[:properties] = process_attributes(obj[:properties]) if obj.key?(:properties)

        obj
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
          type = "String"
          values = value[:list].map do |item|
            type, value = process_value(item)
            value
          end
          ["#{type}[]", values]
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
          type = "String"
          values = value.map do |item|
            type, value = process_value(item)
            value
          end
          ["#{type}[]", values]
        else
          [value.class.to_s, value]
        end
      end
    end
  end
end