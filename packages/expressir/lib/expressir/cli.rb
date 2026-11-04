require "thor"
require "yaml"

module Expressir
  class Cli < Thor
    # Exit with error code on command failures
    def self.exit_on_failure?
      true
    end

    desc "format PATH", "pretty print EXPRESS schema located at PATH"
    method_option :profile, type: :string,
                            desc: "Formatting profile: 'iso' (ISO/TC 184/SC 4) or 'elf' (ELF Pretty Print)",
                            default: "iso"
    method_option :indent, type: :numeric,
                           desc: "Indentation width (ELF profile only)",
                           default: 4
    method_option :provenance, type: :boolean,
                               desc: "Include provenance information (ELF profile only)",
                               default: true
    def format(path, _thor_options = nil)
      Expressir::Commands::Format.new(options).run(path)
    end

    desc "clean PATH", "Strip remarks and prettify EXPRESS schema at PATH"
    method_option :output, type: :string,
                           desc: "Output file path (defaults to stdout)"
    def clean(path, _thor_options = nil)
      Expressir::Commands::Clean.new(options).run(path)
    end

    desc "fix PATH",
         "Rewrite self-schema-qualified references (#125) in the EXPRESS schema at PATH"
    method_option :output, type: :string,
                           aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    def fix(path, _thor_options = nil)
      Expressir::Commands::Fix.new(options).run(path)
    end

    desc "expand PATH",
         "Concatenate the interface closure of PATH into one .exp artifact"
    method_option :output, type: :string,
                           aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    method_option :manifest, type: :string,
                             desc: "ELF schema manifest YAML defining where schemas live " \
                                   "(primary resolution mode)"
    method_option :stepmod, type: :string,
                            desc: "STEPmod checkout root — explicit opt-in to directory-" \
                                  "convention resolution as the fallback"
    def expand(path, _thor_options = nil)
      Expressir::Commands::Expand.new(options).run(path)
    end

    desc "flatten PATH",
         "Flatten the interface closure of PATH into an ISO 10303-11:1994 longform schema"
    method_option :output, type: :string,
                           aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    method_option :longform_name, type: :string,
                                  desc: "Longform SCHEMA id (default: <root>_lf)"
    method_option :extenders, type: :string,
                              desc: "Extensible type handling: 'all' (default, fold every " \
                                    "extender in the closure per Annex G.2.3/G.2.4) or " \
                                    "'none' (leave extensible types as declared)"
    method_option :manifest, type: :string,
                             desc: "ELF schema manifest YAML defining where schemas live " \
                                   "(primary resolution mode)"
    method_option :stepmod, type: :string,
                            desc: "STEPmod checkout root — explicit opt-in to directory-" \
                                  "convention resolution as the fallback"
    def flatten(path, _thor_options = nil)
      Expressir::Commands::Flatten.new(options).run(path)
    end

    desc "benchmark FILE_OR_YAML",
         "Benchmark schema loading performance for a file or list of files from YAML"
    method_option :ips, type: :boolean,
                        desc: "Use benchmark-ips for detailed statistics"
    method_option :verbose, type: :boolean, desc: "Show verbose output"
    method_option :save, type: :boolean, desc: "Save benchmark results to file"
    method_option :format, type: :string,
                           desc: "Output format (json, csv, default)"
    def benchmark(path, _thor_options = nil)
      Expressir::Commands::Benchmark.new(options).run(path)
    end

    desc "benchmark-cache FILE_OR_YAML", "Benchmark schema loading with caching"
    method_option :ips, type: :boolean,
                        desc: "Use benchmark-ips for detailed statistics"
    method_option :verbose, type: :boolean, desc: "Show verbose output"
    method_option :save, type: :boolean, desc: "Save benchmark results to file"
    method_option :format, type: :string,
                           desc: "Output format (json, csv, default)"
    method_option :cache_path, type: :string,
                               desc: "Path to store the cache file"
    def benchmark_cache(path, _thor_options = nil)
      Expressir::Commands::BenchmarkCache.new(options).run(path)
    end

    desc "mapping_validate PATH", "Validate <<express:...>> links in a module mapping.yaml against its ARM/MIM closure"
    def mapping_validate(path)
      Expressir::Commands::MappingValidate.new(options).run(path)
    end

    desc "xsd PATH", "Write an XML Schema rendering of the EXPRESS schema at PATH"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    def xsd(path)
      Expressir::Commands::Xsd.new(options).run(path)
    end

    desc "export-json-schema PATH",
         "Write a JSON Schema rendering of the first EXPRESS schema at PATH"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    def export_json_schema(path)
      Expressir::Commands::ExportJsonSchema.new(options).run(path)
    end

    desc "export-owl PATH",
         "Write an OWL/Turtle rendering of the first EXPRESS schema at PATH"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    method_option :base_iri, type: :string,
                             desc: "Ontology IRI base (default: expressir.org/owl/<schema>#)"
    def export_owl(path)
      Expressir::Commands::ExportOwl.new(options).run(path)
    end

    desc "compare BASE REVISED", "Compare two EXPRESS files; write the schema.changes interchange report"
    option :output, type: :string, aliases: "-o",
                    desc: "Report path (defaults to stdout)"
    def compare(base_path, revised_path)
      Expressir::Commands::Compare.new(options).run(base_path, revised_path)
    end

    desc "doctor DIR", "Assess a workspace for expressir readiness"
    option :emit_manifest, type: :string, desc: "Write a starter schema manifest listing the ready schemas"
    def doctor(path)
      Expressir::Commands::Doctor.new(options).run(path)
    end

    desc "xml-index DIR", "Write the SMRL index XML for every EXPRESS schema under DIR"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path (defaults to stdout)"
    def xml_index(path)
      Expressir::Commands::SmrlXmlIndex.new(options).run(path)
    end

    desc "validate SUBCOMMAND", "EXPRESS schema validation commands"
    subcommand "validate", Expressir::Commands::Validate

    desc "population SUBCOMMAND", "Part 21 dataset validation commands"
    subcommand "population", Expressir::Commands::Population

    desc "receipt MANIFEST",
         "Run schema, dataset and mapping validation over one workspace " \
         "manifest; emit the unified canonical-JSON receipt"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Receipt path (defaults to stdout)"
    def receipt(manifest_path)
      Expressir::Commands::Receipt.new(options).run(manifest_path)
    end

    desc "coverage *PATH",
         "List EXPRESS entities and check documentation coverage"
    method_option :format, type: :string,
                           desc: "Output format (text, json, yaml)", default: "text"
    method_option :exclude, type: :string,
                            desc: "Comma-separated list of EXPRESS entity types to skip from coverage (e.g., TYPE,CONSTANT,TYPE:SELECT)"
    method_option :output, type: :string,
                           desc: "Output file path for JSON/YAML formats (defaults to coverage_report.json/yaml)"
    method_option :ignore_files, type: :string,
                                 desc: "Path to YAML file containing array of files to ignore from overall coverage calculation"
    method_option :max_processes, type: :numeric,
                                  default: Expressir::Express::ParallelFiles::DEFAULT_MAX_PROCESSES,
                                  desc: "Parallel parse workers (1 = sequential; falls back to sequential where fork is unavailable)"
    def coverage(*paths)
      Expressir::Commands::Coverage.new(options).run(paths)
    end

    desc "changes SUBCOMMAND", "Commands for EXPRESS Changes files"
    subcommand "changes", Expressir::Commands::Changes

    desc "manifest SUBCOMMAND", "Schema manifest management commands"
    subcommand "manifest", Expressir::Commands::Manifest

    desc "package SUBCOMMAND", "LER package management commands"
    subcommand "package", Expressir::Commands::Package

    desc "version", "Expressir Version"
    def version
      Expressir::Commands::Version.new(options).run
    end
  end
end
