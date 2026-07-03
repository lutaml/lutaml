# frozen_string_literal: true

require "lutaml/model"
require_relative "encoding_rule"

module Lutaml
  module Schema
    # Bridges a UML {Lutaml::Uml::Document} to lutaml-model's schema emitters.
    #
    # For each UML class it synthesizes a lutaml-model +Serializable+ subclass
    # whose attributes and +xml do ... end+ mapping are derived from the class's
    # attributes via an {EncodingRule}, then delegates to lutaml-model:
    # +Lutaml::Model::Schema.to_xsd+ for XSD and
    # +Lutaml::Json::Schema::JsonSchema.generate+ for JSON Schema. The
    # synthesized class is given a real +name+ (anonymous classes crash JSON
    # Schema generation).
    #
    # @example
    #   bridge = Lutaml::Schema::Bridge.new(repository.document)
    #   File.write("address.xsd", bridge.to_xsd("Address"))
    #   File.write("address.json", bridge.to_json_schema("Address"))
    class Bridge
      # UML primitive name => lutaml-model type symbol. Unknown types (including
      # references to other classes) fall back to string for now; richer type
      # realization is a follow-up.
      PRIMITIVE_TYPES = {
        "string" => :string, "integer" => :integer, "int" => :integer,
        "boolean" => :boolean, "bool" => :boolean, "float" => :float,
        "double" => :float, "real" => :float, "decimal" => :decimal,
        "date" => :date
      }.freeze

      # An XML NCName (no namespace colon): a UML attribute name must be one to
      # be realized as an element/attribute name.
      NCNAME = /\A[A-Za-z_][\w.-]*\z/

      def initialize(document, encoding_rule: EncodingRule.new)
        @document = document
        @encoding_rule = encoding_rule
        @synthesized = {}
      end

      # @return [Array<String>] names of UML classes the bridge can realize
      def class_names
        uml_classes.filter_map(&:name)
      end

      # @param class_name [String] the UML class to realize
      # @return [String] the XSD document
      def to_xsd(class_name)
        require "lutaml/xml"
        Lutaml::Model::Schema.to_xsd(serializable_for(class_name))
      end

      # @param class_name [String] the UML class to realize
      # @return [String] the (pretty) JSON Schema document
      def to_json_schema(class_name)
        require "lutaml/json"
        Lutaml::Json::Schema::JsonSchema.generate(
          serializable_for(class_name), pretty: true
        )
      end

      # Ruby attribute name / XML node name for a UML attribute. The UML name is
      # used VERBATIM (not sanitized): lutaml-model's XSD emitter derives an
      # element's name from the Ruby attribute key, not the mapping name, so
      # sanitizing here would corrupt element names. Names are validated as XML
      # NCNames before a class is synthesized. Public for the synthesized-class
      # closures.
      def attr_key(attribute)
        xml_name(attribute).to_sym
      end

      def xml_name(attribute)
        attribute.name.to_s.strip
      end

      # lutaml-model type symbol for a UML attribute's declared type.
      def primitive_for(attribute)
        PRIMITIVE_TYPES.fetch(attribute.type.to_s.strip.downcase, :string)
      end

      private

      def serializable_for(class_name)
        uml = uml_class(class_name)
        unless uml
          raise ArgumentError,
                "No class named #{class_name.inspect}. " \
                "Available: #{class_names.uniq.sort.join(', ')}"
        end

        @synthesized[uml.name] ||= build_serializable(uml)
      end

      def build_serializable(uml) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        validate_class_name!(uml)
        classified = @encoding_rule.classify(realizable_attributes(uml))
        elements = classified[:elements]
        xml_attributes = classified[:attributes]
        name = uml.name
        bridge = self

        ::Class.new(Lutaml::Model::Serializable) do
          (elements + xml_attributes).each do |field|
            attribute bridge.attr_key(field), bridge.primitive_for(field)
          end

          xml do
            root name
            elements.each do |field|
              map_element bridge.xml_name(field), to: bridge.attr_key(field)
            end
            xml_attributes.each do |field|
              map_attribute bridge.xml_name(field), to: bridge.attr_key(field)
            end
          end

          # Anonymous classes have name == nil, which crashes JSON Schema
          # generation (nil.gsub); give the synthesized class the UML name.
          define_singleton_method(:name) { name }
        end
      end

      # Attributes we can realize: drop blank-named ones, then fail loudly on
      # names that are not valid XML names or that collide, rather than emit a
      # silently wrong schema.
      def realizable_attributes(uml)
        attributes = (uml.attributes || []).to_a
          .reject { |attribute| attribute.name.to_s.strip.empty? }
        names = attributes.map { |attribute| attribute.name.to_s.strip }
        validate_xml_names!(uml, names)
        validate_unique_names!(uml, names)
        attributes
      end

      def validate_xml_names!(uml, names)
        invalid = names.grep_v(NCNAME)
        return if invalid.empty?

        raise ArgumentError,
              "Class #{uml.name.inspect} has attribute name(s) that are not " \
              "valid XML names: #{invalid.join(', ')}"
      end

      def validate_unique_names!(uml, names)
        duplicates = names.tally.select { |_name, count| count > 1 }.keys
        return if duplicates.empty?

        raise ArgumentError,
              "Class #{uml.name.inspect} has duplicate attribute name(s): " \
              "#{duplicates.join(', ')}"
      end

      # The class name becomes the XSD root element name and the JSON Schema
      # definition/$ref key, so it must be a valid XML name too (attribute
      # names are already validated in #realizable_attributes). Fail loudly
      # rather than emit an invalid schema or an unescaped $ref.
      def validate_class_name!(uml)
        return if uml.name.to_s.match?(NCNAME)

        raise ArgumentError,
              "Class #{uml.name.inspect} is not a valid XML name and cannot " \
              "be realized as an XSD root / JSON Schema definition name."
      end

      def uml_classes
        @uml_classes ||= collect_classes(@document)
      end

      # Realizing by simple name; duplicate simple names across packages are
      # ambiguous (qualified-name selection is a follow-up).
      def uml_class(class_name)
        matches = uml_classes.select { |klass| klass.name == class_name }
        if matches.size > 1
          raise ArgumentError,
                "#{matches.size} classes are named #{class_name.inspect}; the " \
                "bridge cannot disambiguate them by simple name."
        end
        matches.first
      end

      # UML classes across the whole package tree (Document/Package both expose
      # +classes+ and +packages+).
      def collect_classes(container)
        direct = (container.classes || []).to_a
        nested = (container.packages || []).to_a
          .flat_map { |package| collect_classes(package) }
        direct + nested
      end
    end
  end
end
