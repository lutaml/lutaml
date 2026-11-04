# frozen_string_literal: true

module Expressir
  module P21
    # Emits a {Population} back to ISO 10303-21 text (TODO.instance/03).
    # Deterministic: the same population always serializes to the same
    # bytes — HEADER entities in insertion order, DATA instances in id
    # order, anchors/references/named sections re-emitted when present.
    module Writer
      module_function

      def emit(population)
        lines = ["ISO-10303-21;", "HEADER;"]
        population.header.each do |keyword, params|
          lines << "#{keyword}(#{emit_params(params)});"
        end
        lines << "ENDSEC;"
        unless population.anchors.empty?
          lines << "ANCHOR;"
          population.anchors.each do |label, value|
            lines << "<#{label}> = #{emit_value(value)};"
          end
          lines << "ENDSEC;"
        end
        unless population.references.empty?
          lines << "REFERENCE;"
          population.references.each do |id, anchor|
            lines << "#{id} = #{anchor};"
          end
          lines << "ENDSEC;"
        end
        emit_data_sections(population, lines)
        lines << "END-ISO-10303-21;"
        "#{lines.join("\n")}\n"
      end

      def emit_data_sections(population, lines)
        if population.sections.empty?
          lines << "DATA;"
          emit_instances(population.instances, lines)
          lines << "ENDSEC;"
          return
        end

        population.sections.each do |section|
          lines << named_data_line(section)
          section.instance_ids.each do |id|
            lines << "#{id}=#{emit_record(population.instances[id])};"
          end
          lines << "ENDSEC;"
        end
      end

      def named_data_line(section)
        return "DATA;" if section.name.nil?

        contexts = section.contexts
          .map { |context| "'#{context}'" }.join(", ")
        "DATA ('#{section.name}', (#{contexts}));"
      end

      def emit_instances(instances, lines)
        instances.each do |id, record|
          lines << "#{id}=#{emit_record(record)};"
        end
      end

      def emit_record(record)
        if record.is_a?(ComplexRecord)
          "(#{record.records.map { |part| emit_simple(part) }.join})"
        else
          emit_simple(record)
        end
      end

      def emit_simple(record)
        "#{record.keyword}(#{emit_params(record.params)})"
      end

      def emit_params(params)
        params.map { |value| emit_value(value) }.join(",")
      end

      def emit_value(value)
        case value
        when Array then "(#{value.map { |item| emit_value(item) }.join(',')})"
        when TypedValue
          "#{value.keyword}(#{emit_params(value.value)})"
        when Enumeration then ".#{value.name}."
        when Binary then "\"#{value.hex}\""
        when :unset then "$"
        when :derived then "*"
        when true then ".T."
        when false then ".F."
        when String then string_or_reference(value)
        else value.to_s
        end
      end

      def string_or_reference(value)
        return value if value.match?(/\A#\d+\z/)

        "'#{value.gsub("'", "''")}'"
      end
    end
  end
end
