# frozen_string_literal: true

module Expressir
  module Lsp
    # The cross-document view used by the server: open documents, schema
    # resolution through USE/REFERENCE interfaces, diagnostics, navigation
    # and rename computation.
    class Workspace
      SEVERITIES = { error: 1, warning: 2, info: 3, hint: 4 }.freeze

      attr_reader :documents

      def initialize
        @documents = {}
      end

      def open(uri:, text:, path: nil)
        @documents[uri] = Document.new(uri: uri, text: text, path: path)
      end

      def change(uri:, text:)
        document = @documents[uri]
        return document.update(text) if document

        self.open(uri: uri, text: text)
      end

      def close(uri)
        @documents.delete(uri)
      end

      def document(uri)
        @documents[uri]
      end

      def symbols(uri)
        document(uri)&.symbols || []
      end

      def diagnostics(uri)
        document = @documents[uri]
        return [] unless document

        return [parse_diagnostic(document)] if document.parse_error

        checker_notes.filter_map { |note| diagnostic_for(document, note) }
      end

      def definition(uri, position)
        target = target_at(uri, position)
        return nil unless target

        location(target[:doc], target[:node])
      end

      def references(uri, position, include_declaration: true)
        target = target_at(uri, position)
        return [] unless target

        declaration = target[:node]
        results = reference_locations(declaration)
        results << location(target[:doc], declaration) if include_declaration
        dedupe_locations(results)
      end

      def hover(uri, position)
        target = target_at(uri, position)
        return nil unless target

        value = Express::PrettyFormatter.new.format(target[:node])
        {
          "contents" => {
            "kind" => "markdown",
            "value" => "```express\n#{value}\n```",
          },
        }
      rescue StandardError
        nil
      end

      def prepare_rename(uri, position)
        target = target_at(uri, position)
        return nil unless target

        document = target[:doc]
        node = target[:node]
        { "range" => document.range_for(node),
          "placeholder" => node.id.to_s }
      end

      # Returns the URI→edits map for a rename, after applying the edits
      # in memory and verifying that every affected document still parses.
      def rename(uri, position, new_name)
        target = target_at(uri, position)
        return nil unless target

        edits = rename_edits(target[:doc], target[:node], new_name)
        verify_rename!(edits, target[:node], new_name)
        { "changes" => edits }
      end

      private

      def checker_notes
        key = @documents.each_value.map { |doc| doc.text.hash }
        return @checker_notes if key == @checker_notes_key

        files = @documents.each_value.filter_map(&:file)
        notes = if files.empty?
                  []
                else
                  repository = Model::Repository.new(files: files)
                  Express::Checker.new(repository).check.notes
                end
        @checker_notes = notes
        @checker_notes_key = key
        notes
      rescue StandardError
        []
      end

      def diagnostic_for(document, note)
        schema = document.schemas.find do |candidate|
          candidate.id.to_s.casecmp?(note.schema.to_s)
        end
        return nil unless schema
        return nil if resolved_note?(document, note)

        node = note.node
        range = if node&.source_offset
                  document.range(node.source_offset,
                                 node.respond_to?(:id) && node.id ? node.id.to_s.bytesize : 1)
                else
                  document.range_for(schema)
                end
        {
          "range" => range,
          "severity" => SEVERITIES.fetch(note.severity, 3),
          "code" => note.id,
          "source" => "expressir",
          "message" => note.message.to_s,
        }
      end

      # The checker sees one file at a time; an open document that supplies
      # the referenced schema or interfaced declaration is not unresolved.
      def resolved_note?(document, note)
        return false unless note.id == :check_unresolved_ref
        return false unless note.node.is_a?(Model::References::SimpleReference)

        !resolve_reference(document, note.node).nil? ||
          !schema_by_id(note.node.id).nil?
      rescue StandardError
        false
      end

      def parse_diagnostic(document)
        error = document.parse_error
        message = error.message.to_s
        line = message[/line (\d+)/, 1].to_i
        character = message[/char (\d+)/, 1].to_i
        line = 1 if line.zero?
        character = 1 if character.zero?
        start = { "line" => line - 1, "character" => character - 1 }
        {
          "range" => { "start" => start,
                       "end" => start.merge("character" => start["character"] + 1) },
          "severity" => 1,
          "source" => "expressir",
          "message" => message.lines.first.to_s.strip,
        }
      end

      def target_at(uri, position)
        document = @documents[uri]
        return nil unless document&.file

        token = document.token_at(position)
        return nil unless token

        declaration = document.declaration_nodes.find do |node|
          document.name_offset(node) == token.start_byte &&
            node.id.to_s.casecmp?(token.text)
        end
        return { doc: document, node: declaration, token: token } if declaration

        reference = document.reference_nodes.find do |node|
          node.source_offset == token.start_byte
        end
        return nil unless reference

        resolved = resolve_reference(document, reference)
        resolved && { doc: resolved[:doc], node: resolved[:node], token: token }
      end

      def resolve_reference(document, node)
        schema = schema_of(node)
        return nil unless schema

        local = node.find(node.id)
        if local
          target_doc = document_for_node(local) || document
          return { doc: target_doc, node: local }
        end

        resolve_interface(schema, node.id)
      rescue StandardError
        nil
      end

      def resolve_interface(schema, name)
        Array(schema.interfaces).each do |interface|
          interface_schema = schema_by_id(interface.schema&.id)
          next unless interface_schema

          items = Array(interface.items)
          if items.empty?
            node = interface_schema[:schema].find(name)
            return { doc: interface_schema[:doc], node: node } if node
          else
            items.each do |item|
              local_name = item.id || item.ref&.id
              next unless local_name.to_s.casecmp?(name.to_s)

              node = interface_schema[:schema].find(item.ref&.id)
              return { doc: interface_schema[:doc], node: node } if node
            end
          end
        end
        nil
      end

      def schema_by_id(id)
        return nil unless id

        @documents.each_value do |document|
          document.schemas.each do |schema|
            next unless schema.id.to_s.casecmp?(id.to_s)

            return { doc: document, schema: schema }
          end
        end
        nil
      end

      def document_for_node(node)
        schema = schema_of(node)
        return nil unless schema

        @documents.each_value do |document|
          return document if document.schemas.any? { |candidate| candidate.equal?(schema) }
        end
        nil
      end

      def schema_of(node)
        current = node
        current = current.parent while current && !current.is_a?(Model::Declarations::Schema)
        current
      end

      def location(document, node)
        { "uri" => document.uri, "range" => document.range_for(node) }
      end

      def reference_locations(declaration)
        declaring_schema = schema_of(declaration)
        @documents.each_value.flat_map do |document|
          document.reference_nodes.filter_map do |reference|
            resolved = resolve_reference(document, reference)
            next unless resolved && same_declaration?(resolved[:node], declaration)

            location(document, reference)
          end + interface_locations(document, declaring_schema, declaration)
        end
      end

      def interface_locations(document, declaring_schema, declaration)
        document.schemas.flat_map do |schema|
          Array(schema.interfaces).flat_map do |interface|
            next [] unless interface.schema&.id.to_s.casecmp?(declaring_schema.id.to_s)

            Array(interface.items).filter_map do |item|
              next unless item.ref&.id.to_s.casecmp?(declaration.id.to_s)

              location(document, item.ref)
            end
          end
        end
      end

      def same_declaration?(left, right)
        left.path.to_s.casecmp?(right.path.to_s)
      end

      def rename_edits(declaring_document, declaration, new_name)
        edits = {}
        add_edit(edits, declaring_document, declaration, new_name)

        @documents.each_value do |document|
          document.schemas.each do |schema|
            rename_references(document, schema, declaration, new_name, edits)
            rename_interface_items(document, schema, declaration, new_name, edits)
          end
        end
        edits
      end

      def rename_references(document, schema, declaration, new_name, edits)
        document.reference_nodes.each do |reference|
          next unless schema_of(reference).equal?(schema)
          next unless reference.id.to_s.casecmp?(declaration.id.to_s)

          resolved = resolve_reference(document, reference)
          next unless resolved && same_declaration?(resolved[:node], declaration)

          add_edit(edits, document, reference, new_name)
        end
      end

      def rename_interface_items(document, schema, declaration, new_name, edits)
        Array(schema.interfaces).each do |interface|
          next unless interface.schema&.id.to_s.casecmp?(schema_of(declaration).id.to_s)

          Array(interface.items).each do |item|
            next unless item.ref&.id.to_s.casecmp?(declaration.id.to_s)

            add_edit(edits, document, item.ref, new_name)
          end
        end
      end

      def add_edit(edits, document, node, new_name)
        range = document.range_for(node)
        list = (edits[document.uri] ||= [])
        return if list.any? { |edit| edit["range"] == range }

        list << { "range" => range, "newText" => new_name }
      end

      def verify_rename!(edits, declaration, new_name)
        declaring_schema = schema_of(declaration)
        edits.each do |uri, document_edits|
          document = @documents[uri]
          text = apply_edits(document.text, document_edits)
          probe = Document.new(uri: uri, text: text, path: document.path)
          raise "rename produced invalid EXPRESS in #{uri}" if probe.parse_error

          verify_schema_after_rename(document, probe, declaring_schema,
                                     declaration, new_name, uri)
        end
      end

      # The renamed declaration may disappear under its old path; every
      # other removal is a structure loss and aborts the rename.
      def verify_schema_after_rename(document, probe, declaring_schema,
                                     declaration, _new_name, uri)
        index = document.schemas.index(declaring_schema)
        return unless index

        probe_schema = probe.schemas[index]
        return unless probe_schema

        old_path = "#{declaring_schema.id}.#{declaration.id}".downcase
        unexpected = Express::SchemaCompare
          .compare(declaring_schema, probe_schema)
          .select do |delta|
            delta.op == :removed && delta.path.to_s.downcase != old_path
          end
        raise "rename removed unrelated declarations in #{uri}" if unexpected.any?

        formatted = Express::Formatter.format(probe_schema)
        formatted_probe = Document.new(uri: uri, text: formatted,
                                       path: document.path)
        raise "renamed schema does not format in #{uri}" if formatted_probe.parse_error
      end

      def apply_edits(text, edits)
        scratch = Document.new(uri: "file:///nonexistent", text: text)
        source = text.b
        offsets = edits.map do |edit|
          start_byte = scratch.byte_offset(edit["range"]["start"]["line"],
                                           edit["range"]["start"]["character"])
          end_byte = scratch.byte_offset(edit["range"]["end"]["line"],
                                         edit["range"]["end"]["character"])
          [start_byte, end_byte, edit["newText"].b]
        end
        offsets.sort_by { |start_byte, _, _| -start_byte }.each do |start_byte, end_byte, replacement|
          source[start_byte...end_byte] = replacement
        end
        source.force_encoding(Encoding::UTF_8)
      end

      def dedupe_locations(locations)
        locations.uniq do |location|
          [location["uri"], location["range"]["start"]["line"],
           location["range"]["start"]["character"]]
        end
      end
    end
  end
end
