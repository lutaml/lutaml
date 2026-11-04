# frozen_string_literal: true

require "moxml"

module Lutaml
  module Xsd
    module Conformance
      # Runs the conformance corpus: one directory per case under
      # spec/conformance/cases/, each holding schema.xsd plus
      # valid-*.xml / invalid-*.xml instances.
      #
      # Two modes are measured independently:
      # - :engine   — Moxml::XSD tier-1 validation (when the adapter
      #               ships an engine)
      # - :pipeline — the production Validator stack (ValidationJob with
      #               the default rule registry)
      #
      # The report is a pass-rate per mode; conformance is a number.
      class Runner
        MODES = %i[engine pipeline].freeze

        Case = Struct.new(:name, :schema_path, :valid, :invalid,
                          keyword_init: true)
        Result = Struct.new(:case_name, :mode, :passed, :total, :failures,
                            :unsupported, keyword_init: true) do
          def pass_rate
            total.zero? ? 0.0 : passed.to_f / total
          end
        end

        # Minimal repository shape the validation stack consumes.
        class Repository
          # @param schemas [Hash] namespace => parsed Schema
          # @param locations [Hash] source path => parsed Schema, for
          #   engines that resolve relative imports from a file location
          def initialize(schemas, locations = {})
            @schemas = schemas
            @locations = locations
          end

          attr_reader :schemas

          def all_schemas
            @schemas
          end

          # @return [String, nil] the file the schema was parsed from
          def source_path_for(schema)
            @locations.find { |_path, candidate| candidate.equal?(schema) }
              &.first
          end
        end

        def initialize(cases_dir)
          @cases_dir = cases_dir
        end

        def cases
          Dir.glob(File.join(@cases_dir, "*")).filter_map do |dir|
            next unless File.directory?(dir)

            schema = File.join(dir, "schema.xsd")
            next unless File.exist?(schema)

            Case.new(
              name: File.basename(dir),
              schema_path: schema,
              valid: Dir.glob(File.join(dir, "valid-*.xml")),
              invalid: Dir.glob(File.join(dir, "invalid-*.xml")),
            )
          end
        end

        # @return [Array<Result>]
        def run
          cases.flat_map do |kase|
            MODES.map { |mode| run_case(kase, mode) }
          end
        end

        # @return [String] human-readable report
        def report(results)
          lines = ["Conformance report", "=" * 60]
          results.group_by(&:mode).each do |mode, mode_results|
            supported = mode_results.reject(&:unsupported)
            passed = supported.sum(&:passed)
            total = supported.sum(&:total)
            rate = total.zero? ? 0.0 : (passed.to_f / total * 100).round(1)
            lines << format("%-10s %3d/%-3d checks (%5.1f%%)%s",
                            mode, passed, total, rate,
                            skipped_note(mode_results))
            mode_results.each do |r|
              next if r.unsupported

              marker = r.failures.empty? ? "ok  " : "FAIL"
              lines << format("  %s %-26s %d/%d",
                              marker, r.case_name, r.passed, r.total)
              r.failures.each { |f| lines << "         - #{f}" }
            end
          end
          lines.join("\n")
        end

        private

        def skipped_note(results)
          skipped = results.count(&:unsupported)
          skipped.zero? ? "" : " (#{skipped} cases unsupported)"
        end

        def run_case(kase, mode)
          checks = kase.valid.map { |path| [path, true] } +
            kase.invalid.map { |path| [path, false] }

          results = checks.map do |path, expected|
            actual = validate(kase, path, mode)
            [path, expected, actual]
          end

          unsupported = results.any? { |_, _, actual| actual == :unsupported }
          failures = results.reject do |_path, expected, actual|
            actual == :unsupported || expected == actual
          end.map { |path, expected, _| "#{File.basename(path)} (expected #{expected ? 'valid' : 'invalid'})" }

          Result.new(
            case_name: kase.name,
            mode: mode,
            passed: unsupported ? 0 : results.count { |_, expected, actual| expected == actual },
            total: unsupported ? 0 : results.length,
            failures: failures,
            unsupported: unsupported,
          )
        end

        def validate(kase, instance_path, mode)
          case mode
          when :engine then engine_valid?(kase, instance_path)
          when :pipeline then pipeline_valid?(kase, instance_path)
          end
        end

        def engine_valid?(kase, instance_path)
          engine = engine_for(kase)
          return :unsupported unless engine&.supported?

          engine.findings_for(File.read(instance_path)).empty?
        end

        def pipeline_valid?(kase, instance_path)
          config = Validation::ValidationConfiguration.new
          job = Validation::ValidationJob.new(
            xml_content: File.read(instance_path),
            repository: repository_for(kase),
            rule_registry: Validation::RuleRegistry.default(config),
            config: config,
          )
          job.execute.valid?
        end

        def engine_for(kase)
          @engine_cache ||= {}
          @engine_cache[kase.name] ||= Validation::EngineContext.compile(
            repository_for(kase),
          )
        end

        def repository_for(kase)
          @repository_cache ||= {}
          @repository_cache[kase.name] ||= begin
            schema = Lutaml::Xml::Schema::Xsd.parse(
              File.read(kase.schema_path), location: kase.schema_path
            )
            Repository.new(schema.target_namespace.to_s => schema)
          end
        end
      end
    end
  end
end
