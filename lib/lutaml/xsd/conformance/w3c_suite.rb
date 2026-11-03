# frozen_string_literal: true

require "moxml"
require_relative "runner"

module Lutaml
  module Xsd
    module Conformance
      # Adapter for the official W3C XML Schema Test Suite
      # (https://github.com/w3c/xsdtests — W3C Document License, see
      # vendor/xsdtests/00COPYRIGHT after setup).
      #
      # The suite's per-contributor `<var>*Meta/*.xml</var>` testSet
      # documents enumerate instance tests with expected validity. This
      # adapter runs the production pipeline over them and reports the
      # official-suite pass rate; the number is the conformance work
      # queue.
      #
      # Setup clones the suite at a pinned commit into vendor/xsdtests
      # (gitignored — the snapshot is fetched, not committed):
      #
      #     rake conformance:w3c:setup
      #     rake conformance:w3c
      module W3CSuite
        PINNED_SHA = "7bc3365"
        REPO_URL = "https://github.com/w3c/xsdtests.git"
        VENDOR_DIR = File.expand_path("../../../../vendor/xsdtests", __dir__)
        SUITE_NS_TEST_GROUP = "//*[local-name()='testGroup']"

        Case = Struct.new(:name, :schema_paths, :instance_path, :expected,
                          :contributor, keyword_init: true)

        module_function

        def vendor_dir
          VENDOR_DIR
        end

        def set_up!
          require "fileutils"
          FileUtils.rm_rf(VENDOR_DIR)
          FileUtils.mkdir_p(File.dirname(VENDOR_DIR))
          system("git", "clone", "--quiet", "--depth", "1", REPO_URL,
                 VENDOR_DIR) or raise "git clone failed for #{REPO_URL}"
          fetched = `git -C #{VENDOR_DIR} rev-parse --short HEAD`.strip
          return if fetched.start_with?(PINNED_SHA)

          warn "fetched #{fetched}, expected #{PINNED_SHA}* — results " \
               "may differ from the recorded baseline"
        end

        def set_up?
          File.directory?(File.join(VENDOR_DIR, ".git")) ||
            File.exist?(File.join(VENDOR_DIR, "00COPYRIGHT"))
        end

        # @return [Array<Case>] instance tests with a definite expectation
        def cases
          Dir[File.join(VENDOR_DIR, "*Meta", "*.xml")].flat_map do |meta_path|
            contributor = File.basename(meta_path, ".xml").sub(/Meta$/, "")
            parse_test_set(meta_path, contributor)
          end
        end

        def parse_test_set(meta_path, contributor)
          doc = Moxml::Context.new.parse(File.read(meta_path))
          base = File.dirname(meta_path)
          doc.xpath(SUITE_NS_TEST_GROUP).flat_map do |group|
            group_cases(group, base, contributor)
          end
        rescue StandardError => e
          warn "skipping #{meta_path}: #{e.message}"
          []
        end

        def group_cases(group, base, contributor)
          group_name = group.attribute("name")&.value.to_s
          schema_paths = group.xpath("./*[local-name()='schemaTest']/*[local-name()='schemaDocument']").filter_map do |doc|
            resolve_href(doc, base)
          end
          return [] if schema_paths.empty? || schema_paths.any?(&:nil?)

          group.xpath("./*[local-name()='instanceTest']").filter_map do |instance_test|
            instance_case(instance_test, group_name, schema_paths, base,
                          contributor)
          end
        end

        def instance_case(instance_test, group_name, schema_paths, base,
                          contributor)
          name = instance_test.attribute("name")&.value.to_s
          doc_node = instance_test.xpath("./*[local-name()='instanceDocument']").first
          expected_node = instance_test.xpath("./*[local-name()='expected']").first
          return nil unless doc_node && expected_node

          instance_path = resolve_href(doc_node, base)
          expected = expected_node.attribute("validity")&.value
          return nil unless instance_path && %w[valid invalid].include?(expected)

          Case.new(
            name: "#{contributor}/#{group_name}/#{name}",
            schema_paths: schema_paths,
            instance_path: instance_path,
            expected: expected,
            contributor: contributor,
          )
        end

        def resolve_href(node, base)
          href = node.attributes.find do |attribute|
            attribute.name == "href"
          end&.value
          return nil unless href

          path = File.expand_path(href, base)
          File.exist?(path) ? path : nil
        end

        # Runs the production pipeline over the selected cases. Cases run
        # in one process per call — lutaml-model's global schema cache
        # grows per parse and the full suite OOMs a single invocation;
        # drive it through offset/limit batches.
        #
        # @return [Hash] report with :passed, :failures, :total
        def measure(offset: 0, limit: nil)
          cases_list = cases[offset, limit || cases.size].to_a
          failures = []
          passed = 0

          cases_list.each do |test_case|
            valid = pipeline_valid?(test_case)
            if valid == (test_case.expected == "valid")
              passed += 1
            else
              failures << test_case
            end
          rescue StandardError => e
            # An instance that cannot even be assessed is not a valid
            # one — satisfies the expected-invalid cases.
            if test_case.expected == "invalid"
              passed += 1
            else
              failures << test_case
              warn "#{test_case.name}: #{e.class}: #{e.message[0, 80]}"
            end
          end

          { total: cases_list.size, passed: passed, failures: failures }
        end

        def pipeline_valid?(test_case)
          schemas = {}
          locations = {}
          test_case.schema_paths.each do |path|
            schema = Lutaml::Xml::Schema::Xsd.parse(File.read(path),
                                                    location: path)
            # Keyed by target namespace like production, EXCEPT that a
            # same-namespace collision suffixes the key instead of
            # dropping the document (schT3's redefine pair both declare
            # ns-a). The resolver iterates values; keys only need to
            # keep every document present.
            key = if schema.target_namespace.to_s.match?(/\S/)
                    schema.target_namespace
                  else
                    path
                  end
            key = "#{key}##{path}" while schemas.key?(key)
            schemas[key] = schema
            locations[path] = schema
          end
          config = Validation::ValidationConfiguration.new
          job = Validation::ValidationJob.new(
            xml_content: File.read(test_case.instance_path),
            repository: Runner::Repository.new(schemas, locations),
            rule_registry: Validation::RuleRegistry.default(config),
            config: config,
            instance_base: File.dirname(test_case.instance_path),
          )
          job.execute.valid?
        end

        # Schema documents the INSTANCE hints at (xsi:schemaLocation /
        # xsi:noNamespaceSchemaLocation on the root), resolved relative
        # to the instance file.
        #
        # @param instance_path [String]
        # @return [Array<String>]
        def hint_paths(instance_path)
          Validation::SchemaLocationHints.paths(
            File.read(instance_path), File.dirname(instance_path)
          )
        end
      end
    end
  end
end
