# frozen_string_literal: true

module Expressir
  module Commands
    # `expressir compare` (TODO.compat/01): compare two EXPRESS files
    # and emit the `schema.changes` interchange report — the format
    # the `changes` importer reads, so comparison data flows both ways
    # across toolchains.
    class Compare < Base
      KINDS = {
        constants: "CONSTANT",
        types: "TYPE",
        entities: "ENTITY",
        subtype_constraints: "SUBTYPE_CONSTRAINT",
        functions: "FUNCTION",
        rules: "RULE",
        procedures: "PROCEDURE",
      }.freeze

      def run(base_path, revised_path)
        base_repo = Expressir::Express::Parser.from_file(base_path)
        revised_repo = Expressir::Express::Parser.from_file(revised_path)
        report = build_report(base_repo, revised_repo)
        xml = serialize(report)
        if options[:output]
          File.write(options[:output], xml)
          say "report written to #{options[:output]}"
        else
          $stdout.write(xml)
        end
      end

      # Emitted through Moxml directly: lutaml-model's leptris-backed
      # serializer mis-parses the interchange's dotted element names
      # ("schema.changes") as namespace prefixes and fails the build
      # (same upstream family as lutaml-model#997). The model layer
      # stays lutaml-model; the XML face is Moxml.
      def serialize(report)
        ctx = Moxml::Context.new
        doc = ctx.create_document
        root = doc.create_element("schema.changes")
        doc.add_child(root)
        {
          "schema.additions" => report.additions,
          "schema.deletions" => report.deletions,
          "schema.modifications" => report.modifications,
        }.each do |name, section|
          root.add_child(section_node(doc, name, section))
        end
        doc.to_xml
      end

      def section_node(doc, name, section)
        node = doc.create_element(name)
        Array(section&.modified_objects).each do |obj|
          node.add_child(object_node(doc, obj))
        end
        node
      end

      def object_node(doc, obj)
        node = doc.create_element("modified.object")
        attrs = { "type" => obj.type, "name" => obj.name }
        attrs["interfaced.items"] = obj.interfaced_items if obj.interfaced_items
        attrs["classif"] = obj.classif if obj.classif
        node.set_attributes(attrs)
        if obj.description
          desc = doc.create_element("description")
          desc.content = obj.description
          node.add_child(desc)
        end
        node
      end

      def build_report(base_repo, revised_repo)
        sections = { additions: [], deletions: [], modifications: [] }
        base = index_schemas(base_repo)
        revised = index_schemas(revised_repo)

        (base.keys | revised.keys).each do |schema_id|
          base_schema = base[schema_id]
          revised_schema = revised[schema_id]
          if base_schema.nil?
            collect_whole_schema(revised_schema, :added, sections)
          elsif revised_schema.nil?
            collect_whole_schema(base_schema, :removed, sections)
          else
            collect_deltas(base_schema, revised_schema, sections)
          end
        end

        Expressir::Eengine::CompareReport.new(
          additions: Expressir::Eengine::ChangesSection
            .new(modified_objects: sections[:additions]),
          deletions: Expressir::Eengine::ChangesSection
            .new(modified_objects: sections[:deletions]),
          modifications: Expressir::Eengine::ChangesSection
            .new(modified_objects: sections[:modifications]),
        )
      end

      def index_schemas(repo)
        Array(repo.schemas).to_h do |schema|
          [schema.id&.safe_downcase, schema]
        end
      end

      def collect_whole_schema(schema, operation, sections)
        section = section_for(operation)
        Expressir::Express::SchemaCompare::COLLECTIONS.each do |collection|
          Array(schema.send(collection)).each do |decl|
            next unless decl.respond_to?(:id) && decl.id

            sections[section] << Expressir::Eengine::ModifiedObject.new(
              type: KINDS[collection], name: decl.id,
            )
          end
        end
      end

      def collect_deltas(base_schema, revised_schema, sections)
        Expressir::Express::SchemaCompare::COLLECTIONS.each do |collection|
          deltas = Expressir::Express::SchemaCompare
            .collection_deltas(base_schema, revised_schema, collection)
          Expressir::Express::ChangeClassification.apply(deltas, base_schema)
          deltas.each do |delta|
            # an attribute-level delta modifies its entity: it lands
            # in modifications whatever the op
            section = if delta.path.split(".").size > 2
                        :modifications
                      else
                        section_for(delta.op)
                      end
            sections[section] << object_for(delta, collection)
          end
        end
      end

      def object_for(delta, collection)
        kind = KINDS[collection]
        name = delta.path.split(".").last
        object = if delta.path.split(".").size > 2
                   # attribute-level delta: the qualified path is the name
                   Expressir::Eengine::ModifiedObject.new(
                     type: kind, name: delta.path,
                     description: "attribute #{delta.op}"
                   )
                 else
                   Expressir::Eengine::ModifiedObject.new(type: kind, name: name)
                 end
        object.classif = delta.classification&.value
        object
      end

      def section_for(operation)
        case operation
        when :added then :additions
        when :removed then :deletions
        else :modifications
        end
      end

      def kind_of(declaration)
        case declaration
        when Model::Declarations::Entity then "ENTITY"
        when Model::Declarations::Type then "TYPE"
        when Model::Declarations::Function then "FUNCTION"
        when Model::Declarations::Rule then "RULE"
        when Model::Declarations::SubtypeConstraint then "SUBTYPE_CONSTRAINT"
        when Model::Declarations::Constant then "CONSTANT"
        when Model::Declarations::Procedure then "PROCEDURE"
        else declaration.class.name.split("::").last.upcase
        end
      end
    end
  end
end
