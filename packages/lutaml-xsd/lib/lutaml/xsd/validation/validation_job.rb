# frozen_string_literal: true

require_relative "validation_result"
require_relative "validation_error"
require_relative "xml_navigator"
require_relative "result_collector"
require_relative "rule_engine"
require_relative "unique_particle_attribution"

module Lutaml
  module Xsd
    module Validation
      # ValidationJob executes the validation workflow
      #
      # This class implements the Command pattern to execute XML validation
      # against XSD schemas. It coordinates the validation process through
      # multiple phases: XML parsing, structure validation, type validation,
      # and constraint validation.
      #
      # @example Execute a validation job
      #   job = ValidationJob.new(
      #     xml_content: "<root>...</root>",
      #     repository: schema_repository,
      #     rule_registry: rule_registry,
      #     config: configuration
      #   )
      #   result = job.execute
      class ValidationJob
        # Initialize a new ValidationJob
        #
        # @param xml_content [String] The XML content to validate
        # @param repository [SchemaRepository] The schema repository
        # @param rule_registry [RuleRegistry] Registry of validation rules
        # @param config [ValidationConfiguration] Validation configuration
        # @param instance_base [String, nil] directory the instance was
        #   read from — when given, xsi:schemaLocation /
        #   xsi:noNamespaceSchemaLocation hints that resolve layer over
        #   the package repository; without it hints are ignored
        #
        # @raise [ArgumentError] if required parameters are missing
        def initialize(xml_content:, repository:, rule_registry:, config:,
                       instance_base: nil)
          @xml_content = xml_content
          @instance_base = instance_base
          # Instance-hinted schemas (xsi:schemaLocation) layer over the
          # package when the caller provides the instance's directory —
          # relative hints never resolve against the working directory.
          if @instance_base
            hinted = HintedSchemaRepository.from_hints(
              repository, xml_content, @instance_base
            )
            repository = hinted if hinted
          end
          @repository = repository
          @rule_registry = rule_registry
          @config = config
          @result_collector = ResultCollector.new(config)
          @navigator = nil
          @document = nil
          @rule_engine = nil
        end

        # Execute the validation workflow
        #
        # Performs validation in the following order:
        # 1. Parse XML document
        # 2. Engine-native XSD validation (when the adapter provides one)
        # 3. Validate structure (elements, namespaces)
        # 4. Validate types (simple and complex types)
        # 5. Validate constraints (occurrences, identity constraints)
        #
        # @return [ValidationResult] The complete validation result
        def execute
          return early_result if should_stop_early?

          parse_xml
          return result_from_collector if should_stop_after_parse?

          validate_root_declaration
          run_engine_validation if @config.feature_enabled?(:engine_validation)
          run_upa_validation if @config.feature_enabled?(:validate_upa)
          validate_structure if @config.feature_enabled?(:validate_types)
          return result_from_collector if should_stop_after_structure?

          validate_types if @config.feature_enabled?(:validate_types)
          return result_from_collector if should_stop_after_types?

          validate_constraints if @config.feature_enabled?(:validate_occurrences)
          return result_from_collector if should_stop_after_constraints?

          validate_identity if @config.feature_enabled?(:validate_identity_constraints)
          arbitrate_engine_findings

          result_from_collector
        end

        private

        # An instance whose root element is not declared by any schema in
        # the package can never be valid; surface it explicitly (the
        # engine's root-matching stays silent for unknown roots, and the
        # rule engine skips unresolved declarations by design). A root
        # carrying a RESOLVABLE xsi:type is assessed against that type
        # instead (addB187) — the check only fires when nothing anchors
        # the document.
        #
        # @return [void]
        def validate_root_declaration
          root = @document&.root_element
          return unless root

          resolver = SchemaDefinitionResolver.new(@repository)
          return if resolver.resolve(root.name, root.namespace_uri)
          return if overridable_root?(root, resolver)

          @result_collector.add_error(
            ValidationError.new(
              code: "element_not_allowed",
              message: "Root element '#{root.name}' is not declared by any " \
                       "schema in the package",
              severity: :error,
              location: root.xpath,
              context: {
                element: root.name,
                namespace: root.namespace_uri,
              },
            ),
          )
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Whether the root anchors itself through xsi:type naming a type
        # the package defines (XSD assessment of an undeclared root with
        # an override).
        #
        # @return [Boolean]
        def overridable_root?(root, resolver)
          override = root.attributes.find do |attribute|
            attribute.name == "type" &&
              attribute.namespace_uri ==
                "http://www.w3.org/2001/XMLSchema-instance"
          end
          local = override && override.value.to_s.split(":").last
          !local.nil? && resolver.resolve_named_type(local)
        end

        # Validate identity constraints (key/keyref/unique)
        #
        # @return [void]
        def validate_identity
          return unless @document && @rule_engine

          @rule_engine.execute_category(:identity, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # The engine's identity-unique check compares values LEXICALLY,
        # so its duplicate findings for a constraint the Ruby rule
        # evaluated clean are value-space false positives (idF012/013/
        # 014: same lexical, disjoint primitives). The Ruby rule engine
        # is authoritative for value spaces — arbitrate those findings
        # out after the identity pass. Findings for constraints the Ruby
        # rule never evaluated stay (the engine may see wider scopes).
        #
        # @return [void]
        def arbitrate_engine_findings
          evaluated = @rule_registry.rules_for_category(:identity)
            .find { |rule| rule.is_a?(Rules::IdentityConstraintsRule) }
            &.evaluated_constraints
          return unless evaluated

          @result_collector.errors.reject! do |error|
            next false unless error.code == EngineContext::ENGINE_CODE

            name = duplicate_constraint_name(error.message)
            !name.nil? && evaluated.include?(name)
          end
        end

        # @return [String, nil] the constraint name a DUPLICATE-shaped
        #   engine message names — the arbitration must not touch the
        #   other engine findings (idG006's missing-field message shares
        #   the "key 'N':" prefix but is not a value-space claim)
        def duplicate_constraint_name(message)
          head = message.match(/\A(?:unique|key(?:ref)?)\s+'([^']+)':/i)
          return head && head[1] if head && message.match?(/duplicate/i)

          tail = message.match(/\ADuplicate .* for '([^']+)'\z/i)
          tail && tail[1]
        end

        # Schema-side UPA checking (XSD 1.0 3.8.6). Findings describe the
        # schema rather than the instance, so they surface as warnings.
        #
        # @return [void]
        def run_upa_validation
          @repository.all_schemas.each_value do |schema|
            UniqueParticleAttribution.new(schema).findings.each do |finding|
              @result_collector.add_warning(
                ValidationError.new(
                  code: finding.code,
                  message: finding.message,
                  severity: :warning,
                  context: { schema_path: finding.path },
                ),
              )
            end
          end
        rescue StandardError => e
          @result_collector.add_warning(
            ValidationError.new(
              code: "upa_validation_unavailable",
              message: "UPA validation skipped: #{e.message}",
              severity: :warning,
            ),
          )
        end

        # Run engine-native XSD validation (Moxml::XSD) when the adapter
        # supports it. Findings are additive to rule findings.
        #
        # @return [void]
        def run_engine_validation
          @engine_context ||= EngineContext.compile(@repository)
          @rule_registry.all_rules(enabled_only: false).each do |rule|
            rule.engine_context = @engine_context if rule.is_a?(EngineBacked)
          end
          return unless @engine_context&.supported?

          @engine_context.findings_for(@xml_content).each do |finding|
            @result_collector.add_error(finding)
          end
          # One-shot job: free the engine-side schema now — native
          # document pools otherwise accumulate across batched suite runs
          # (moxml#350).
          @engine_context.release
        rescue StandardError => e
          @result_collector.add_warning(
            ValidationError.new(
              code: "engine_validation_unavailable",
              message: "Engine validation skipped: #{e.message}",
              severity: :warning,
            ),
          )
        end

        # Parse the XML content into a document object
        #
        # @return [void]
        def parse_xml
          @navigator = XmlNavigator.new(@xml_content)
          @document = @navigator.document
          @rule_engine = RuleEngine.new(@rule_registry, @result_collector)
        rescue Moxml::ParseError => e
          @result_collector.add_error(
            ValidationError.new(
              code: "xml_parse_error",
              message: "Failed to parse XML: #{e.message}",
              severity: :error,
              location: nil,
            ),
          )
        rescue StandardError => e
          @result_collector.add_error(
            ValidationError.new(
              code: "xml_parse_error",
              message: "Unexpected error parsing XML: #{e.message}",
              severity: :error,
              location: nil,
            ),
          )
        end

        # Validate document structure
        #
        # @return [void]
        def validate_structure
          return unless @document && @rule_engine

          @rule_engine.execute_category(:structure, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Validate element types
        #
        # @return [void]
        def validate_types
          return unless @document && @rule_engine

          @rule_engine.execute_category(:type, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Validate constraints
        #
        # @return [void]
        def validate_constraints
          return unless @document && @rule_engine

          @rule_engine.execute_category(:constraint, @document, @repository)
          @rule_engine.execute_category(:facet, @document, @repository)
          @rule_engine.execute_category(:identity, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Check if validation should stop early
        #
        # @return [Boolean]
        def should_stop_early?
          @xml_content.nil? || @xml_content.empty?
        end

        # Check if validation should stop after parse
        #
        # @return [Boolean]
        def should_stop_after_parse?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Check if validation should stop after structure validation
        #
        # @return [Boolean]
        def should_stop_after_structure?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Check if validation should stop after type validation
        #
        # @return [Boolean]
        def should_stop_after_types?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Check if validation should stop after constraint validation
        #
        # @return [Boolean]
        def should_stop_after_constraints?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Build early result for invalid input
        #
        # @return [ValidationResult]
        def early_result
          @result_collector.add_error(
            ValidationError.new(
              code: "invalid_input",
              message: "XML content cannot be nil or empty",
              severity: :error,
              location: nil,
            ),
          )
          result_from_collector
        end

        # Build result from collector
        #
        # @return [ValidationResult]
        def result_from_collector
          @result_collector.to_result
        end
      end
    end
  end
end
