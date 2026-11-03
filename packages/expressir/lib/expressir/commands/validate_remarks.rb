# frozen_string_literal: true

require_relative "base"

module Expressir
  module Commands
    # Source-stage remark validation. Three checks:
    #
    # * a block anchor ([[name]]) defined in more than one remark scope
    #   of the same schema — documents rendered from both scopes then
    #   carry duplicated anchor attributes and fail the backend's
    #   unique-ID validation;
    # * a remark item describing a LOCAL variable of a FUNCTION that the
    #   RETURN statement references — resource documents would print it
    #   under "Argument definitions:" (metanorma/iso-10303#763); the
    #   result belongs in the body of the FUNCTION description;
    # * [.svgmap] list items inside __expressg blocks: the named schema
    #   must exist, the ordinal belongs after the cross-reference, and
    #   the item ordinals must match the hyperlink identifiers of the
    #   diagram the block names (metanorma/iso-10303#743, #744, #745).
    class ValidateRemarks < Base
      BLOCK_ANCHOR = /\A[ \t]*\[\[([^\]]+)\]\][ \t]*\r?\n?\z/
      SVG_IMAGE = /\A[ \t]*image::([^\[\]]+\.svg)\[\]/
      SVGMAP_ITEM = /\A\*[ \t]+<<express:([^>]*)>>[ \t]*;[ \t]*(\d+)[ \t]*\r?\n?\z/
      SVGMAP_ORDINAL_INSIDE = /\A\*[ \t]+<<express:[^>]*;\s*\d+[^>]*>>/
      SVG_HREF = /<a href="([^"]*)"/

      def run(paths)
        if paths.size == 1 && File.extname(paths.first) == ".yaml"
          validate_from_manifest(paths.first)
        else
          validate_from_paths(paths)
        end
      end

      private

      def validate_from_manifest(manifest_path)
        unless File.exist?(manifest_path)
          raise Expressir::ManifestNotFoundError.new(manifest_path)
        end

        manifest = Expressir::SchemaManifest.from_file(manifest_path)
        paths = manifest.schemas.map(&:path).reject { |p| p.nil? || p.empty? }
        if paths.empty?
          raise Expressir::NoValidSchemaPathsError.new(
            "No valid schema paths found in manifest",
          )
        end

        validate_from_paths(paths)
      end

      def validate_from_paths(paths)
        files = schema_paths(paths)
        # The parses fan out across forked workers (issue #584); a
        # parse failure raises in input order, exactly like the
        # sequential pass did. Small sets stay sequential (the
        # facility's own threshold).
        parse = ->(path) { Expressir::Express::Parser.from_file(path) }
        results =
          if Expressir::Express::ParallelFiles.sequential?(files, jobs_count)
            files.map { |path| parse.call(path) }
          else
            Expressir::Express::ParallelFiles.run(
              files, parse: parse, max_processes: jobs_count, strict: true
            )
          end
        parsed = files.zip(results)
          .filter_map { |path, repository| repository && [path, repository.schemas] }
        schema_ids = parsed.flat_map { |_, schemas| schemas.map(&:id) }
          .map { |id| id.to_s.downcase }

        violations = []
        parsed.each do |path, schemas|
          schemas.each do |schema|
            violations.concat(duplicate_anchor_violations(schema, path))
            violations.concat(returned_local_violations(schema, path))
            violations.concat(svgmap_violations(schema, path, schema_ids))
          end
        end

        if violations.empty?
          say "Validation passed: no duplicate remark block anchors, no " \
              "returned-LOCAL descriptions, and no svgmap defects."
          return
        end

        say "#{'*' * 20} RESULTS: REMARK VALIDATION #{'*' * 20}"
        violations.each { |violation| say violation }
        raise Expressir::SchemaValidationError.new(
          "Remark validation failed: #{violations.size} violation(s)",
          errors: violations,
        )
      end

      def schema_paths(paths)
        paths.flat_map do |path|
          if File.directory?(path)
            Dir.glob(File.join(path, "**", "*.exp"))
          else
            path
          end
        end
      end

      def duplicate_anchor_violations(schema, path)
        definitions = Hash.new { |hash, anchor| hash[anchor] = [] }
        remark_scopes(schema).each do |label, remarks|
          each_remark_line(remarks) do |line|
            match = line.match(BLOCK_ANCHOR)
            next unless match

            definitions[match[1]] << label
          end
        end

        definitions.filter_map do |anchor, labels|
          next if labels.size == 1

          "Duplicate remark block anchor `#{anchor}` defined in " \
            "#{labels.join(', ')} | schema `#{schema.id}` | #{path}"
        end
      end

      def returned_local_violations(schema, path)
        Array(schema.children)
          .grep(Expressir::Model::Declarations::Function)
          .flat_map do |function|
            returned = returned_identifiers(function)
            Array(function.variables).filter_map do |variable|
              next unless returned.include?(variable.id.to_s.downcase)
              next if Array(variable.remarks)
                .map { |remark| remark.to_s.strip }.reject(&:empty?).empty?

              "LOCAL variable `#{variable.id}` of FUNCTION " \
                "`#{function.id}` is referenced in the RETURN statement " \
                "and carries a description; describe the result in the " \
                "body of the FUNCTION description instead | schema " \
                "`#{schema.id}` | #{path}"
            end
          end
      end

      # Identifiers referenced by any RETURN statement of the function,
      # including returns nested in IF/CASE and other compound
      # statements.
      def returned_identifiers(function)
        refs = []
        seen = {}.compare_by_identity
        returns = []
        collect = lambda do |node|
          return if node.nil? || seen.key?(node)

          seen[node] = true
          returns << node if node.is_a?(Expressir::Model::Statements::Return)
          node.class.attributes.each_key do |attr|
            value = begin
              node.public_send(attr)
            rescue StandardError
              next
            end
            Array(value).each do |child|
              collect.call(child) if child.is_a?(Expressir::Model::ModelElement)
            end
          end
        end
        Array(function.statements).each { |statement| collect.call(statement) }
        returns.each do |ret|
          seen_expr = {}.compare_by_identity
          expr_walk = lambda do |node|
            next if node.nil? || seen_expr.key?(node)

            seen_expr[node] = true
            if node.is_a?(Expressir::Model::References::SimpleReference) &&
                node.id
              refs << node.id.to_s.downcase
            end
            node.class.attributes.each_key do |attr|
              value = begin
                node.public_send(attr)
              rescue StandardError
                next
              end
              Array(value).each do |child|
                expr_walk.call(child) if child.is_a?(
                  Expressir::Model::ModelElement,
                )
              end
            end
          end
          expr_walk.call(ret.expression)
        end
        refs.uniq
      end

      def svgmap_violations(schema, path, schema_ids)
        dir = File.dirname(path)
        blocks = svgmap_blocks(schema, schema_ids)
        blocks.flat_map do |items|
          violations = items[:violations]
          violations.concat(items[:malformed].map do |line|
            "svgmap item places the ordinal inside the cross-reference; " \
              "write `<<express:TARGET>>; N` instead: #{line.strip} " \
              "| schema `#{schema.id}` | #{path}"
          end)
          violations.concat(items[:unknown_schemas].map do |name|
            "svgmap item names schema `#{name}`, which is not declared in " \
              "the repository | schema `#{schema.id}` | #{path}"
          end)
          violations.concat(
            ordinal_mismatches(File.join(dir, items[:svg]), items, path,
                               schema.id),
          )
          violations
        end
      end

      def svgmap_blocks(schema, schema_ids)
        current = nil
        blocks = []
        Array(schema.remark_items)
          .select { |item| item.id == "__expressg" }
          .each do |item|
            each_remark_line(Array(item.remarks)) do |line|
              image = line.match(SVG_IMAGE)
              if image
                current = { svg: image[1],
                            violations: [],
                            malformed: [],
                            unknown_schemas: [],
                            ordinals: [] }
                blocks << current
                next
              end
              next unless current

              if line.match?(SVGMAP_ORDINAL_INSIDE)
                current[:malformed] << line
                next
              end

              item_match = line.match(SVGMAP_ITEM)
              next unless item_match

              current[:ordinals] << item_match[2]
              name = item_match[1].to_s.sub(/\A\.+/, "").split(".").first
              if name && !schema_ids.include?(name.downcase)
                current[:unknown_schemas] << name
              end
            end
          end
        blocks
      end

      def ordinal_mismatches(svg_path, items, path, schema_id)
        return [] unless File.exist?(svg_path)

        svg = File.read(svg_path)
        # Only numeric hyperlink identifiers are svgmap keys; named
        # hrefs mark imported-schema regions no list item claims.
        svg_ids = svg.scan(SVG_HREF).flatten.map(&:strip)
          .grep(/\A\d+\z/).uniq
        ordinals = items[:ordinals].uniq
        [].concat(
          (ordinals - svg_ids).map do |ordinal|
            "svgmap ordinal `#{ordinal}` has no hyperlink in " \
              "`#{File.basename(svg_path)}` | schema `#{schema_id}` | #{path}"
          end,
          (svg_ids - ordinals).map do |id|
            "svgmap hyperlink `#{id}` in `#{File.basename(svg_path)}` is " \
              "claimed by no list item | schema `#{schema_id}` | #{path}"
          end,
        )
      end

      def each_remark_line(remarks, &block)
        Array(remarks).each do |text|
          next if text.nil?

          source = text.is_a?(String) ? text : text.to_s
          source.each_line(&block)
        end
      end

      def remark_scopes(schema)
        scopes = [["the untagged schema remark", Array(schema.remarks)]]
        Array(schema.remark_items).each do |item|
          scopes << ["remark item `#{item.id}`", Array(item.remarks)]
        end
        scopes
      end
    end
  end
end
