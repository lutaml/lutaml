# frozen_string_literal: true

module Expressir
  module Express
    # Builds the concatenated EXPRESS artifact (expressir#247): the
    # root schema plus every schema reachable through USE FROM /
    # REFERENCE FROM, one section per source schema, ordered
    # alphabetically by schema name — the Express Engine
    # `--concat_schema` semantics.
    module Concatenator
      module_function

      # Schemas of the interface closure of `root_schema`, deduplicated
      # by name and sorted alphabetically — the exact set and order the
      # concatenated artifact contains. `repository` must hold every
      # schema the closure can reach.
      def closure(root_schema, repository)
        by_name = repository.schemas.to_h { |s| [s.id.safe_downcase, s] }
        visited = {}
        queue = [root_schema]
        until queue.empty?
          schema = queue.shift
          key = schema.id.safe_downcase
          next if visited.key?(key)

          visited[key] = schema
          Array(schema.interfaces).each do |iface|
            target = interface_target(iface, by_name)
            queue << target if target && !visited.key?(target.id.safe_downcase)
          end
        end
        visited.values.sort_by { |s| s.id.safe_downcase }
      end

      def interface_target(iface, by_name)
        name = iface.schema.is_a?(String) ? iface.schema : iface.schema&.id
        return nil unless name

        by_name[name.safe_downcase]
      end

      # Writes the artifact: a provenance banner, the schema index
      # (name, file, version), then each source file verbatim behind a
      # `-- NAME (file)` separator.
      def write(io, schemas)
        io.puts "(* Concatenated File produced by Expressir #{Expressir::Version::VERSION}"
        io.puts
        io.puts "#{schemas.size} Schemata for Concatenated File"
        io.puts
        schemas.each do |schema|
          io.puts schema.id.safe_downcase
          io.puts "   Filename: #{schema.file}"
          io.puts "   Version:   #{schema.version&.value}" if schema.version
          io.puts
        end
        io.puts " *)"
        io.puts
        schemas.each do |schema|
          io.puts "--"
          io.puts "-- #{schema.id.upcase} (#{schema.file})"
          io.puts "--"
          io.write(File.read(schema.file))
          io.puts
          io.puts
        end
      end

      # One-call convenience: closure of the root schema found in
      # `repository`, written to `path`.
      def call(root_schema, repository, path)
        schemas = closure(root_schema, repository)
        File.open(path, "w") do |file|
          write(file, schemas)
        end
        schemas
      end
    end
  end
end
