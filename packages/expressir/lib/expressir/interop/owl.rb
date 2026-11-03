# frozen_string_literal: true

module Expressir
  module Interop
    # OWL 2 / RDF Turtle rendering of an EXPRESS schema, in the ifcOWL
    # lineage generalized to arbitrary EXPRESS (docs/interop/owl-rdf.md).
    # Entities become owl:Class with rdfs:subClassOf per supertype;
    # explicit attributes become properties with rdfs:domain/rdfs:range;
    # SELECT becomes an owl:unionOf equivalent class; ENUMERATION items
    # become individuals of the enumeration class. WHERE rules are not
    # exported (documented scope limit).
    class Owl
      PREFIXES = {
        "owl" => "http://www.w3.org/2002/07/owl#",
        "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
      }.freeze

      PRIMITIVE_RANGES = {
        Model::DataTypes::Integer => "xsd:integer",
        Model::DataTypes::Real => "xsd:double",
        Model::DataTypes::Number => "xsd:double",
        Model::DataTypes::String => "xsd:string",
        Model::DataTypes::Boolean => "xsd:boolean",
        Model::DataTypes::Logical => "xsd:boolean",
        Model::DataTypes::Binary => "xsd:hexBinary",
      }.freeze

      def self.export(schema, base_iri: nil)
        new(schema, base_iri: base_iri).export
      end

      attr_reader :schema, :base_iri

      def initialize(schema, base_iri: nil)
        @schema = schema
        @base_iri = base_iri || "https://expressir.org/owl/#{schema.id}#"
      end

      def export
        blocks = [ontology_block]
        Array(schema.types).each { |type| blocks.concat(type_blocks(type)) }
        Array(schema.entities).each { |entity| blocks.concat(entity_blocks(entity)) }
        ([prefix_block, ""] + blocks).join("\n")
      end

      private

      def prefix_block
        prefixes = { "ex" => base_iri }.merge(PREFIXES)
        prefixes.map { |name, iri| "@prefix #{name}: <#{iri}> ." }.join("\n")
      end

      def ontology_block
        block(["a owl:Ontology", "rdfs:label #{quote(schema.id.to_s)}"],
              subject: "<#{base_iri}>")
      end

      def entity_blocks(entity)
        lines = ["a owl:Class", "rdfs:label #{quote(entity.id.to_s)}"]
        supertypes = Array(entity.subtype_of)
        if supertypes.any?
          parents = supertypes.map { |parent| "ex:#{parent.id}" }
          lines << "rdfs:subClassOf #{parents.join(', ')}"
        end
        lines << "rdfs:comment #{quote('EXPRESS ABSTRACT SUPERTYPE')}" if entity.abstract
        [block(lines, subject: "ex:#{entity.id}")] + attribute_blocks(entity)
      end

      def attribute_blocks(entity)
        explicit_attributes(entity).map do |attribute|
          range = range_for(attribute.type)
          lines = ["a #{property_kind(attribute.type)}",
                   "rdfs:domain ex:#{entity.id}",
                   "rdfs:range #{range}"]
          lines << "rdfs:comment #{quote('OPTIONAL')}" if attribute.optional
          block(lines, subject: "ex:#{attribute.id}")
        end
      end

      def explicit_attributes(entity)
        Array(entity.attributes)
          .select { |attribute| attribute.instance_of?(Model::Declarations::Attribute) }
      end

      def type_blocks(type)
        underlying = type.underlying_type
        case underlying
        when Model::DataTypes::Enumeration
          enumeration_blocks(type.id, underlying)
        when Model::DataTypes::Select
          [select_block(type.id, underlying)]
        else
          [defined_type_block(type.id, underlying)]
        end
      end

      def enumeration_blocks(name, enumeration)
        values = enumeration_values(enumeration)
        blocks = [block(["a owl:Class", "rdfs:label #{quote(name.to_s)}"],
                        subject: "ex:#{name}")]
        values.each do |value|
          blocks << "ex:#{value} a owl:NamedIndividual, ex:#{name} ."
        end
        blocks
      end

      def enumeration_values(enumeration, seen = [])
        return [] if enumeration.nil? || seen.include?(enumeration.object_id)

        seen += [enumeration.object_id]
        values = []
        base_type = resolve_reference(enumeration.based_on)
        if base_type&.underlying_type.is_a?(Model::DataTypes::Enumeration)
          values.concat(enumeration_values(base_type.underlying_type, seen))
        end
        values.concat(Array(enumeration.items).filter_map(&:id))
        values.uniq
      end

      def select_block(name, select)
        items = select_items(select).map { |item| "ex:#{item}" }
        block(
          ["a owl:Class",
           "rdfs:label #{quote(name.to_s)}",
           "owl:equivalentClass [ a owl:Class ; owl:unionOf ( #{items.join(' ')} ) ]"],
          subject: "ex:#{name}",
        )
      end

      def select_items(select, seen = [])
        return [] if select.nil? || seen.include?(select.object_id)

        seen += [select.object_id]
        names = []
        base_type = resolve_reference(select.based_on)
        if base_type&.underlying_type.is_a?(Model::DataTypes::Select)
          names.concat(select_items(base_type.underlying_type, seen))
        end
        names.concat(Array(select.items).filter_map(&:id))
        names.uniq
      end

      def defined_type_block(name, underlying)
        primitive = PRIMITIVE_RANGES[underlying.class]
        lines = ["a #{primitive ? 'rdfs:Datatype' : 'owl:Class'}",
                 "rdfs:label #{quote(name.to_s)}"]
        lines << if primitive
                   "owl:equivalentClass #{primitive}"
                 elsif underlying.is_a?(Model::References::SimpleReference)
                   "rdfs:subClassOf ex:#{underlying.id}"
                 else
                   "rdfs:subClassOf rdf:List"
                 end
        block(lines, subject: "ex:#{name}")
      end

      def property_kind(type)
        object_property?(type) ? "owl:ObjectProperty" : "owl:DatatypeProperty"
      end

      def object_property?(type, seen = [])
        case type
        when Model::DataTypes::List, Model::DataTypes::Array,
             Model::DataTypes::Set, Model::DataTypes::Bag,
             Model::DataTypes::Select, Model::DataTypes::Enumeration
          true
        when Model::References::SimpleReference
          return false if seen.include?(type.id)

          target = resolve_reference(type)
          case target
          when Model::Declarations::Entity then true
          when Model::Declarations::Type
            object_property?(target.underlying_type, seen + [type.id])
          else false
          end
        else false
        end
      end

      def range_for(type)
        case type
        when Model::DataTypes::List, Model::DataTypes::Array,
             Model::DataTypes::Set, Model::DataTypes::Bag
          "rdf:List"
        when Model::DataTypes::Enumeration, Model::DataTypes::Select
          "rdfs:Resource"
        when Model::References::SimpleReference
          "ex:#{type.id}"
        else
          PRIMITIVE_RANGES[type.class] || "rdfs:Resource"
        end
      end

      def resolve_reference(reference)
        return nil unless reference.respond_to?(:id) && reference.id

        schema.find(reference.id)
      rescue StandardError
        nil
      end

      def block(predicates, subject: nil)
        head = subject ? "#{subject} #{predicates.first}" : predicates.first
        rest = predicates.drop(1).map { |line| "    #{line}" }
        "#{([head] + rest).join(" ;\n")} ."
      end

      def quote(text)
        JSON.generate(text)
      end
    end
  end
end
