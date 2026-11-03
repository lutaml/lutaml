# frozen_string_literal: true

module Expressir
  module P21
    # Turns a {Grammar} capture tree into a {Population}.
    module Builder
      module_function

      def build(tree)
        header = build_header(tree[:header_section])
        instances = {}
        sections = []
        data_sections(tree).each do |section|
          records = build_instances(section)
          instances.update(records)
          sections << build_section(section, records.keys)
        end
        Population.new(
          header: header, instances: instances, sections: sections,
          anchors: build_anchors(tree[:anchor_section]),
          references: build_references(tree[:reference_section])
        )
      end

      # A DATA section capture: hash for a single section, array when
      # the exchange structure carries several (ISO 10303-21 annex E).
      def data_sections(tree)
        sections = tree[:data_section]
        sections = [sections] unless sections.is_a?(Array)
        sections.compact.map do |section|
          # The repeat's own capture nests each section one level deep.
          inner = section[:data_section]
          inner.is_a?(Hash) ? inner : section
        end
      end

      Section = Struct.new(:name, :contexts, :instance_ids,
                           keyword_init: true)

      def build_section(section, instance_ids)
        tag = section[:section_tag]
        values = tag && parameter_list_values(tag.is_a?(Hash) ? { parameter: tag } : tag)
        name = values && values.first.is_a?(String) ? values.first : nil
        contexts = values && values[1].is_a?(Array) ? values[1] : []
        Section.new(name: name, contexts: contexts, instance_ids: instance_ids)
      end

      def build_anchors(capture)
        entries = capture.is_a?(Hash) ? [capture] : Array(capture)
        unwrap_anchor_entries(entries).filter_map do |entry|
          next unless entry.is_a?(Hash) && entry[:anchor_label]

          value = entry[:entity_instance_name] ||
            (entry[:unset] ? :unset : nil)
          [entry[:anchor_label].to_s,
           value == :unset ? :unset : "##{value.to_s.delete_prefix('#')}"]
        end.to_h
      end

      # Parsanol captures nest one wrapper per repeat/rule level;
      # collect the leaves that carry the anchor fields.
      def unwrap_anchor_entries(entries)
        entries.flat_map do |entry|
          next [] unless entry.is_a?(Hash)

          inner = entry[:anchor_entry]
          if inner
            unwrap_anchor_entries(inner.is_a?(Array) ? inner : [inner])
          else
            [entry]
          end
        end
      end

      def build_references(capture)
        list = capture.nil? ? [] : capture[:instance_list]
        entries = list.is_a?(Array) ? list : [list]
        entries.filter_map do |entry|
          next unless entry.is_a?(Hash) && entry[:external_reference_instance]

          body = entry[:external_reference_instance]
          ["##{body[:entity_instance_name].to_s.delete_prefix('#')}",
           body[:external_anchor].to_s]
        end.to_h
      end

      def build_header(section)
        Array(section[:header_entity]).each_with_object({}) do |entry, hash|
          record = entry[:simple_record]
          hash[record_keyword(record)] = record_params(record)
        end
      end

      def build_instances(section)
        list = section[:instance_list]
        entries = list.is_a?(Array) ? list : [list]
        entries.each_with_object({}) do |entry, hash|
          next unless entry.is_a?(Hash)

          if (complex = entry[:complex_entity_instance])
            hash[instance_id(complex)] = build_complex(complex)
          elsif (simple = entry[:simple_entity_instance])
            record = simple[:simple_record]
            hash[instance_id(simple)] = Record.new(record_keyword(record),
                                                   record_params(record))
          end
        end
      end

      def instance_id(body)
        "##{body[:entity_instance_name].to_s.delete_prefix('#')}"
      end

      def build_complex(body)
        subs = body[:subsuper_record]
        subs = [subs] unless subs.is_a?(Array)
        records = subs.map do |sub|
          record = sub[:simple_record]
          Record.new(record_keyword(record), record_params(record))
        end
        ComplexRecord.new(records)
      end

      def record_keyword(record)
        record[:keyword].to_s.delete_prefix("!")
      end

      # A parameter_list capture is a hash when there is a single parameter
      # and an array of {parameter: ...} entries otherwise.
      def parameter_list_values(capture)
        return [] if capture.nil?

        entries = capture.is_a?(Array) ? capture : [capture]
        entries.map { |entry| build_value(entry[:parameter]) }
      end

      def record_params(record)
        parameter_list_values(record[:parameter_list])
      end

      def build_value(param)
        if (typed = param[:typed_parameter])
          TypedValue.new(typed[:keyword].to_s.delete_prefix("!"),
                         parameter_list_values(typed[:parameter_list]))
        elsif param[:parameter_list]
          parameter_list_values(param[:parameter_list])
        elsif param[:entity_instance_name]
          "##{param[:entity_instance_name].to_s.delete_prefix('#')}"
        elsif param[:constant_reference]
          param[:constant_reference].to_s
        elsif param[:number_literal]
          text = param[:number_literal].to_s
          text.match?(/[.Ee]/) ? text.to_f : text.to_i
        elsif param[:enumeration]
          Enumeration.new(param[:enumeration].to_s.delete_prefix(".").delete_suffix("."))
        elsif param[:binary_literal]
          Binary.new(param[:binary_literal].to_s.delete_prefix('"').delete_suffix('"'))
        elsif param[:string_literal]
          param[:string_literal].to_s[1..-2].gsub("''", "'")
        elsif param[:unset]
          :unset
        elsif param[:derived]
          :derived
        end
      end
    end
  end
end
