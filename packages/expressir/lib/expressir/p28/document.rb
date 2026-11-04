# frozen_string_literal: true

module Expressir
  module P28
    # TODO.p28/04: the iso_10303_28 document envelope (clause 9.2.1,
    # annex D). All XML goes through moxml and its leptris adapter —
    # the express/header children and the envelope skeleton are
    # translated by module functions (the same discipline as
    # P28::Uos), and the model layer stays lutaml-model
    # Serializables for attribute typing and collections.
    #
    # Upstream note: lutaml-model 0.8.114's XML builder crashes on
    # the leptris adapter for every mapping
    # (`uninitialized constant Leptris::XML::Declaration`), so the
    # XML face is not delegated to lutaml-model's serializer.
    module Document
      # Clause 9.2.3: an EXPRESS schema by value — id (the local
      # reference target for uos `schema` attributes), schema_name,
      # and the schema source as the element content.
      class ExpressElement < Lutaml::Model::Serializable
        attribute :id, :string
        attribute :schema_name, :string
        attribute :source, :string
      end

      # Clause 5.2.1: the document header element — the Part 21
      # header entities as child elements.
      class Header < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :time_stamp, :string
        attribute :author, :string, collection: true
        attribute :organization, :string, collection: true
        attribute :preprocessor_version, :string
        attribute :originating_system, :string
        attribute :authorization, :string
      end

      module_function

      # @param express [Array<ExpressElement>] schemas by value
      # @param units [Array<String>] serialized uos documents
      #   (`P28::Uos.emit` output), each referencing an express id
      #   through its schema attribute
      # @param header [Header, nil] clause 5.2.1 header
      # @return [String] the iso_10303_28 document
      def emit(express:, units:, header: nil)
        ctx = Moxml::Context.new
        doc = ctx.create_document
        root = doc.create_element("iso_10303_28")
        root.set_attributes("xmlns" => COMMON_NS)
        doc.add_child(root)
        root.add_child(header_node(doc, header)) if header
        express.each { |element| root.add_child(express_node(doc, element)) }
        units.each do |unit|
          root.add_child(Moxml::Context.new.parse(unit).root)
        end
        doc.to_xml
      end

      def express_node(doc, element)
        node = doc.create_element("express")
        node.set_attributes("id" => element.id,
                            "schema_name" => element.schema_name)
        node.content = element.source.to_s
        node
      end

      def header_node(doc, header)
        node = doc.create_element("header")
        {
          "name" => header.name,
          "time_stamp" => header.time_stamp,
          "author" => header.author,
          "organization" => header.organization,
          "preprocessor_version" => header.preprocessor_version,
          "originating_system" => header.originating_system,
          "authorization" => header.authorization,
        }.each do |name, value|
          Array(value).each do |item|
            child = doc.create_element(name)
            child.content = item.to_s
            node.add_child(child)
          end
        end
        node
      end

      # @param xml [String] an iso_10303_28 document
      # @return [Hash] express elements, their parsed EXPRESS
      #   schemas, and the populations of every uos, keyed by the
      #   uos' schema attribute (9.2.6.2: a local reference to an
      #   express element's id)
      def parse(xml)
        root = Moxml::Context.new.parse(xml).root
        unless root&.name == "iso_10303_28"
          raise Expressir::Error,
                "not an iso_10303_28 document (root '#{root&.name}')"
        end

        express = elems(root).filter_map do |node|
          next unless node.name == "express"

          attributes = attrs(node)
          ExpressElement.new(id: attributes["id"],
                             schema_name: attributes["schema_name"],
                             source: node.text)
        end
        schemas = express.to_h do |element|
          [element.id, Expressir::Express::Parser.from_exp(element.source)
            .schemas.first]
        end

        units = {}
        elems(root).each do |node|
          next unless node.name == "uos"

          id = attrs(node)["schema"]
          schema = schemas[id]
          unless schema
            raise Expressir::Error,
                  "uos references unknown express id '#{id}'"
          end

          units[id] = Uos.parse(node.to_xml, schema)
        end
        { express: express, schemas: schemas, units: units }
      end

      def elems(node)
        node.children.grep(Moxml::Element)
      end

      def attrs(node)
        node.attributes.to_h { |a| [a.name, a.value] }
      end
    end
  end
end
