require "find"
require "thor"

module Expressir
  module Commands
    # Common parser/discovery helpers shared by parity CLI commands
    # (expand, flatten, check) — they all need: list of files in the
    # interface closure of a root file, and the root schema parsed.
    #
    # Schema resolution order (per the ELF schema manifest directive):
    #   1. `--manifest PATH` — an ELF schema manifest explicitly defines
    #      where each schema lives; this is the primary mode.
    #   2. `--stepmod DIR` — explicit opt-in to the STEPmod directory
    #      convention (`schemas/**/<name>.exp`) as the fallback.
    #   3. Otherwise the file's own directory is used; a lookup failure
    #      warns and points at the two explicit modes.
    module ParityInputs
      module_function

      # Resolve the transitive interface closure of +root_path+. The queue
      # holds paths and `seen` guards by schema name: mutual USE FROM
      # cycles must terminate (this loop once span rounds forever on them,
      # re-reading the same files).
      def closure_paths(root_path, manifest: nil, stepmod: nil)
        index = schema_index(root_path, manifest: manifest, stepmod: stepmod)
        seen = { File.basename(root_path, ".exp").downcase => root_path }
        missing = []
        queue = [root_path]
        until queue.empty?
          closure_names(File.read(queue.shift)).each do |dep|
            name = dep.downcase
            next if seen.key?(name)

            path = index&.[](name)
            unless path
              missing << name
              seen[name] = nil
              next
            end

            seen[name] = path
            queue << path
          end
        end
        unless missing.empty?
          raise Thor::Error,
                "expressir: schema(s) not found: #{missing.uniq.join(', ')}" \
                "#{resolver_hint(manifest, stepmod)}"
        end
        seen.values.compact.uniq
      end

      def resolver_hint(manifest, stepmod)
        if manifest
          " (not in schema manifest #{manifest})"
        elsif stepmod
          " (not found under STEPmod root #{stepmod})"
        else
          " - provide --manifest PATH (ELF schema manifest) or " \
            "--stepmod DIR to resolve them"
        end
      end

      # Schema-name → path index from the ELF schema manifest. An
      # explicitly given manifest that cannot be loaded is fatal (#455):
      # when the root has no interface dependencies the lookup would
      # never consult the index, so a typo'd --manifest would exit 0.
      def manifest_index(manifest_path)
        manifest = Expressir::SchemaManifest.from_file(manifest_path)
        manifest.schemas.to_h do |entry|
          [entry.id.downcase, entry.path]
        end
      rescue StandardError => e
        raise Thor::Error,
              "expressir: could not load schema manifest #{manifest_path}: #{e.message}"
      end

      # Schema-name → path index over a STEPmod checkout root (the
      # directory holding `schemas/`, or that directory itself).
      def stepmod_index(stepmod_dir)
        root = File.join(File.expand_path(stepmod_dir), "schemas")
        root = File.expand_path(stepmod_dir) unless File.directory?(root)
        h = {}
        Find.find(root) do |path|
          next unless path.end_with?(".exp")

          declared = File.read(path)[/\bSCHEMA\s+(\w+)/i, 1]
          h[declared.downcase] = path if declared
          h[File.basename(path, ".exp").downcase] ||= path
        end
        h
      end

      def schema_index(root_path, manifest: nil, stepmod: nil)
        return manifest_index(manifest) if manifest
        return stepmod_index(stepmod) if stepmod

        # Default: the file's own directory plus, when the root sits
        # inside a STEPmod checkout, its enclosing `schemas/` tree —
        # the layout wg12-step modules live in. Same-directory
        # declarations win over tree hits for the same schema name:
        # the file next to the root is the intentional one (#455).
        index = same_dir_index(root_path)
        ancestor = ancestor_schemas_dir(root_path)
        if ancestor
          tree = stepmod_index(File.dirname(ancestor))
          tree.update(index)
          index = tree
        end
        index
      end

      # Nearest ancestor directory NAMED `schemas`, or nil.
      def ancestor_schemas_dir(root_path)
        dir = File.dirname(File.expand_path(root_path))
        # dirname reaches a fixed point at the filesystem root: "/" on
        # POSIX, "D:/" (or a UNC root) on windows. Comparing against "/"
        # alone spun forever on windows - every rake run since this
        # shipped (e0f6651, 2026-09-24) burned the full 6h runner
        # budget in the first expand example (#487).
        until dir == "/" || dir == File.dirname(dir)
          return dir if File.basename(dir) == "schemas"

          dir = File.dirname(dir)
        end
        nil
      end

      def same_dir_index(root_path)
        dir = File.dirname(File.expand_path(root_path))
        h = {}
        Dir.glob(File.join(dir, "*.exp")).each do |path|
          # index by DECLARED schema name first (a file named arm.exp
          # may declare schema m_arm), basename as fallback
          declared = File.read(path)[/\bSCHEMA\s+(\w+)/i, 1]
          h[declared.downcase] = path if declared
          h[File.basename(path, ".exp").downcase] ||= path
        end
        h
      end

      # Interface names declared by +source+. Remark text is stripped
      # first: prose like "use from the main schema" must not spawn
      # phantom dependencies.
      def closure_names(source)
        code = source.gsub(/--[^\n]*/, "").gsub(/\(\*.*?\*\)/m, "")
        code.scan(/\bUSE\s+FROM\s+(\w+)/i).flatten.uniq +
          code.scan(/\bREFERENCE\s+FROM\s+(\w+)/i).flatten.uniq
      end

      def root_schema(root_path, manifest: nil, stepmod: nil)
        name = File.read(root_path)[/\bSCHEMA\s+(\w+)/, 1]
        # skip_references: longform generation and checking run their own
        # resolution; resolving every reference of a large closure here made
        # flatten crawl (minutes vs seconds).
        repo = Expressir::Express::Parser.from_files(
          closure_paths(root_path, manifest: manifest, stepmod: stepmod),
          skip_references: true,
          max_processes: 1,
        )
        [repo.schemas.find { |s| s.id&.downcase == name&.downcase }, repo]
      end
    end
  end
end
