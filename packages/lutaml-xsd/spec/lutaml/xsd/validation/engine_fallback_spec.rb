# frozen_string_literal: true

require "spec_helper"
require "moxml"
require "lutaml/xsd/validation/engine_context"
require "lutaml/xsd/validation/validation_job"
require "lutaml/xsd/validation/rule_registry"

RSpec.describe "engine validation fallback" do
  let(:rexml_context) { Moxml::Context.new(:rexml) }
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:rule_registry) { Lutaml::Xsd::Validation::RuleRegistry.new(config) }

  let(:xsd_xml) do
    <<~XML
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="date" type="xs:date"/>
      </xs:schema>
    XML
  end
  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_xml) }
  let(:repository) do
    Class.new do
      def initialize(schemas)
        @schemas = schemas
      end

      def all_schemas
        @schemas
      end
    end.new({ "http://example.com/test" => schema })
  end

  it "reports no engine support on REXML (no engine validator)" do
    expect(Lutaml::Xsd::Validation::EngineContext.xsd_supported?(rexml_context))
      .to be(false)
    expect(
      Lutaml::Xsd::Validation::EngineContext.compile(
        repository, context: rexml_context
      ),
    ).to be_nil
  end

  it "runs a validation job without engine findings when no schema compiles" do
    empty_repository = Class.new do
      def all_schemas
        {}
      end
    end.new
    job = Lutaml::Xsd::Validation::ValidationJob.new(
      xml_content: "<date>not-a-date</date>",
      repository: empty_repository,
      rule_registry: rule_registry,
      config: config,
    )

    result = job.execute

    codes = result.errors.map(&:code) + result.warnings.map(&:code)
    expect(codes).not_to include("engine_validation")
    expect(codes).not_to include("engine_validation_unavailable")
  end

  it "keeps the job's engine inert when schemas fail to compile" do
    broken_repository = Class.new do
      def all_schemas
        { "http://example.com/broken" => "not-a-schema-object" }
      end
    end.new
    job = Lutaml::Xsd::Validation::ValidationJob.new(
      xml_content: "<date>not-a-date</date>",
      repository: broken_repository,
      rule_registry: rule_registry,
      config: config,
    )

    result = job.execute

    codes = result.errors.map(&:code) + result.warnings.map(&:code)
    expect(codes).not_to include("engine_validation")
    expect(codes).not_to include("engine_validation_unavailable")
  end
end
