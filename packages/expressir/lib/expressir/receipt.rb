# frozen_string_literal: true

require "json"
require "digest"

module Expressir
  # The unified repository receipt (TODO.compat/04): one deterministic,
  # signing-ready canonical-JSON artifact binding the three shipped
  # validators — schema (Checker), instance datasets (P21) and module
  # mappings (Mapping) — with input digests, generator version and
  # per-rule verdicts. Same manifest + same inputs → byte-identical
  # receipt; signatures cover the canonical serialization.
  module Receipt
    CANONICALIZATION =
      "canonical JSON: recursively sorted object keys, UTF-8, " \
      "no insignificant whitespace; signatures cover these bytes"

    # The workspace manifest: one file driving one receipt. Paths are
    # resolved against the manifest's directory.
    class WorkspaceManifest < Lutaml::Model::Serializable
      attribute :schema_files, :string, collection: true
      attribute :dialect, :string
      attribute :datasets, :string, collection: true
      attribute :mappings, :string, collection: true

      key_value do
        map "schema_files", to: :schema_files
        map "dialect", to: :dialect
        map "datasets", to: :datasets
        map "mappings", to: :mappings
      end

      class << self
        def from_file(path)
          manifest = from_yaml(File.read(path))
          manifest.base_dir = File.dirname(File.expand_path(path))
          manifest.validate_entries!
          manifest
        end
      end

      attr_accessor :base_dir

      def validate_entries!
        return if Array(schema_files).any?

        raise Expressir::ManifestValidationError,
              "workspace manifest lists no schema_files"
      end

      def resolve(path)
        File.expand_path(path, base_dir || ".")
      end

      def schema_paths
        Array(schema_files).map { |f| resolve(f) }
      end

      def dataset_paths
        Array(datasets).map { |f| resolve(f) }
      end

      def mapping_paths
        Array(mappings).map { |f| resolve(f) }
      end
    end

    module_function

    # Canonical serialization: sort every object's keys recursively.
    # Values are scalars, arrays and string-keyed objects only, so the
    # sort is total and the bytes are reproducible.
    def canonicalize(value)
      case value
      when Hash
        value.sort.to_h.transform_values { |v| canonicalize(v) }
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end

    def generate(payload)
      JSON.generate(canonicalize(payload))
    end

    def digest(path)
      Digest::SHA256.hexdigest(File.binread(path))
    end

    # Manifest-relative, slash-normalized keys keep the receipt
    # byte-identical across checkouts.
    def rel_path(path, base_dir)
      path = File.expand_path(path)
      base = File.expand_path(base_dir)
      rel = path.delete_prefix("#{base}/")
      rel.start_with?("/") ? path : rel
    end

    def schema_section(manifest)
      files = manifest.schema_paths.sort
      repository = Expressir::Express::Parser.from_files(files)
      result = Expressir::Express::Checker.new(
        repository, dialect: manifest.dialect
      ).check
      notes = result.notes.map do |note|
        {
          "id" => note.id.to_s,
          "severity" => note.severity.to_s,
          "schema" => note.schema&.id.to_s,
          "message" => note.message,
        }
      end
      {
        "valid" => result.valid?,
        "notes" => notes,
        "errors" => notes.count { |n| n["severity"] == "error" },
        "warnings" => notes.count { |n| n["severity"] == "warning" },
      }
    end

    def dataset_section(manifest_path)
      dataset = Expressir::P21::DatasetManifest.from_file(manifest_path)
      schema = Expressir::Express::Parser.from_file(dataset.schema_path).schemas.first
      files = dataset.file_paths.sort.map do |path|
        population = Expressir::P21::Parser.parse(File.read(path))
        notes = Expressir::P21::Validator.validate(
          population, schema, short_names: dataset.short_name_map
        )
        {
          "path" => File.basename(path),
          "digest" => digest(path),
          "notes" => notes.map do |note|
            {
              "id" => note.id.to_s,
              "severity" => note.severity.to_s,
              "instance" => note.instance,
              "message" => note.message,
            }
          end,
        }
      end
      {
        "manifest" => File.basename(manifest_path),
        "manifest_digest" => digest(manifest_path),
        "release" => dataset.release.to_s,
        "schema" => dataset.schema.to_s,
        "files" => files,
        "errors" => files.sum { |f| f["notes"].count { |n| n["severity"] == "error" } },
        "warnings" => files.sum { |f| f["notes"].count { |n| n["severity"] == "warning" } },
      }
    end

    def mapping_section(manifest, manifest_path)
      document = Expressir::Mapping.load_file(manifest_path)
      repository = mapping_repository(manifest_path)
      unknown = Expressir::Mapping.unknown_links(document, repository)
      issues = mapping_refpath_issues(document, repository)
      rules = Expressir::Mapping.rule_issues(document, repository)
      {
        "file" => rel_path(manifest_path, manifest.base_dir),
        "valid" => [unknown, issues, rules].all?(&:empty?),
        "unknown_links" => unknown.map(&:text).sort,
        "refpath_issues" => issues.map do |location, issue|
          "refpath #{location} [step #{issue.step}]: #{issue.message}"
        end.sort,
        "unknown_rules" => rules.map(&:text).sort,
      }
    end

    def mapping_refpath_issues(document, repository)
      Expressir::Mapping.refpaths(document).flat_map do |location, content|
        parsed = Expressir::Mapping::RefPath.parse(content)
        start = Expressir::Mapping.entity_item(location)
        parsed.parse_errors.map do |error|
          [location, Expressir::Mapping::RefPath::Issue.new(step: nil, message: error)]
        end + Expressir::Mapping::RefPath.validate(parsed, repository,
                                                   start: start)
          .map { |issue| [location, issue] }
      end
    end

    # The ARM/MIM closure next to the mapping file — the same contract
    # as `mapping_validate`.
    def mapping_repository(manifest_path)
      dir = File.dirname(File.expand_path(manifest_path))
      arm = Dir[File.join(dir, "arm.exp")].first
      mim = Dir[File.join(dir, "mim.exp")].first
      roots = [arm, mim].compact
      if roots.empty?
        raise Expressir::ManifestValidationError,
              "no arm.exp/mim.exp next to #{manifest_path}"
      end

      Expressir::Express::Parser.from_files(roots)
    end

    def build(manifest)
      datasets = manifest.dataset_paths.sort.map { |p| dataset_section(p) }
      mappings = manifest.mapping_paths.sort.map { |p| mapping_section(manifest, p) }
      schema = schema_section(manifest)
      errors = schema["errors"] +
        datasets.sum { |d| d["errors"] } +
        mappings.count { |m| !m["valid"] }
      warnings = schema["warnings"] + datasets.sum { |d| d["warnings"] }

      {
        "artifact" => "expressir-receipt",
        "format" => 1,
        "generator" => { "expressir" => Expressir::VERSION },
        "canonicalization" => CANONICALIZATION,
        "inputs" => {
          "schema_files" => manifest.schema_paths.sort.to_h do |path|
            [rel_path(path, manifest.base_dir), digest(path)]
          end,
          "datasets" => datasets.map do |d|
            { "manifest" => d["manifest"], "manifest_digest" => d["manifest_digest"] }
          end,
          "mappings" => mappings.map do |m|
            { "file" => m["file"], "digest" => digest(File.join(manifest.base_dir, m["file"])) }
          end,
        },
        "verdicts" => {
          "schema" => schema,
          "datasets" => datasets,
          "mappings" => mappings,
        },
        "summary" => {
          "valid" => errors.zero?,
          "errors" => errors,
          "warnings" => warnings,
        },
      }
    end
  end
end
