# frozen_string_literal: true

module Expressir
  module P21
    # JSON interchange for populations (TODO.instance/03). Values are
    # tagged so the round trip is value-identical: references stay
    # references, enumerations and binaries stay typed, and `$`/`*`
    # survive as their Part 21 meanings.
    module Json
      module_function

      def to_value(population)
        {
          "header" => population.header,
          "instances" => population.instances.to_h do |id, record|
            [id, record_value(record)]
          end,
          "sections" => population.sections.map do |section|
            { "name" => section.name, "contexts" => section.contexts,
              "instance_ids" => section.instance_ids }
          end,
          "anchors" => population.anchors.to_h do |label, value|
            [label, anchor_value(value)]
          end,
          "references" => population.references,
        }
      end

      def population(value)
        instances = value.fetch("instances").to_h do |id, record|
          [id, record_from(record)]
        end
        sections = value.fetch("sections").map do |section|
          Builder::Section.new(name: section["name"],
                               contexts: section["contexts"],
                               instance_ids: section["instance_ids"])
        end
        anchors = value.fetch("anchors").to_h do |label, anchor|
          [label, anchor == "unset" ? :unset : anchor]
        end
        Population.new(
          header: value.fetch("header"),
          instances: instances,
          sections: sections,
          anchors: anchors,
          references: value.fetch("references"),
        )
      end

      def record_value(record)
        if record.is_a?(ComplexRecord)
          { "complex" => record.records.map { |part| simple_value(part) } }
        else
          simple_value(record)
        end
      end

      def simple_value(record)
        { "keyword" => record.keyword,
          "params" => value_params(record.params) }
      end

      def value_params(params)
        params.map { |value| value_value(value) }
      end

      def value_value(value)
        case value
        when Array then value.map { |item| value_value(item) }
        when TypedValue
          { "typed" => { "keyword" => value.keyword,
                         "value" => value_value(value.value) } }
        when Enumeration then { "enum" => value.name }
        when Binary then { "binary" => value.hex }
        when :unset then { "unset" => true }
        when :derived then { "derived" => true }
        when String
          value.match?(/\A#\d+\z/) ? { "ref" => value } : value
        else value
        end
      end

      def record_from(value)
        if (complex = value["complex"])
          ComplexRecord.new(complex.map { |part| simple_from(part) })
        else
          simple_from(value)
        end
      end

      def simple_from(value)
        Record.new(value.fetch("keyword"), params_from(value.fetch("params")))
      end

      def params_from(params)
        params.map { |value| value_from(value) }
      end

      def value_from(value)
        case value
        when Array then value.map { |item| value_from(item) }
        when Hash
          if (typed = value["typed"])
            TypedValue.new(typed.fetch("keyword"),
                           params_from(Array(typed.fetch("value"))))
          elsif (enum = value["enum"])
            Enumeration.new(enum)
          elsif (binary = value["binary"])
            Binary.new(binary)
          elsif value["unset"]
            :unset
          elsif value["derived"]
            :derived
          elsif (ref = value["ref"])
            ref
          else
            value
          end
        else value
        end
      end

      def anchor_value(value)
        value == :unset ? "unset" : value
      end
    end
  end
end
