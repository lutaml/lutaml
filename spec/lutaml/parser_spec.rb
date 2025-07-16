require "spec_helper"

RSpec.describe Lutaml::Parser do
  describe ".parse" do
    subject(:parse) { described_class.parse(input, input_type) }

    let(:input_type) { nil }

    context "when exp file supplied" do
      let(:input) { File.new(fixtures_path("test-generic.exp")) }

      it "calls Lutaml::Express::Parsers" do
        allow(Expressir::Express::Parser).to receive(:from_files)
        parse
        expect(Expressir::Express::Parser).to have_received(:from_files)
      end
    end

    context "when xmi file supplied" do
      let(:input) { File.new(fixtures_path("ea-xmi-2.4.2-generic.xmi")) }

      it "calls Lutaml::XMI::Parsers::XML" do
        allow(Lutaml::XMI::Parsers::XML).to receive(:parse)
        parse
        expect(Lutaml::XMI::Parsers::XML).to have_received(:parse)
      end
    end

    context "when lutaml file supplied" do
      let(:input) { File.new(fixtures_path("test.lutaml")) }

      it "calls Lutaml::Uml::Parsers::Dsl" do
        allow(Lutaml::Uml::Parsers::Dsl).to receive(:parse)
        parse
        expect(Lutaml::Uml::Parsers::Dsl).to have_received(:parse)
      end
    end

    context "when exp cache yaml file is supplied but it has an old version" do
      let(:input_path) do
        fixtures_path("test-generic.exp_cached_old_version.yaml")
      end
      let(:input) { File.new(input_path) }
      let(:exp_schema_path) { fixtures_path("test-generic.exp") }
      let(:exp_schema_file) { File.new(exp_schema_path) }
      let(:input_type) { "exp.cache" }

      before do
        repository = Expressir::Express::Parser.from_file(exp_schema_path)
        Expressir::Express::Cache.to_file(input_path, repository,
                                          test_overwrite_version: "0.2.21")
      end

      it "raises Expressir::Error" do
        expect do
          Expressir::Express::Cache.from_file(input_path)
        end.to raise_error(Expressir::Express::Error::CacheVersionMismatchError)
      end
    end

    context "when exp cache yaml file supplied and its valid" do
      let(:input_path) { fixtures_path("test-generic.exp_cached_valid.yaml") }
      let(:input) { File.new(input_path) }
      let(:exp_schema_path) { fixtures_path("test-generic.exp") }
      let(:exp_schema_file) { File.new(exp_schema_path) }
      let(:input_type) { "exp.cache" }

      before do
        repository = Expressir::Express::Parser.from_file(exp_schema_path)
        Expressir::Express::Cache.to_file(input_path, repository)
      end

      it "calls Lutaml::Express::Cache" do
        allow(Expressir::Express::Cache)
          .to receive(:from_file).and_call_original
        parse
        expect(Expressir::Express::Cache).to have_received(:from_file)
      end
    end

    context "when xsd file supplied and its valid" do
      let(:input_path) { fixtures_path("schema.xsd") }
      let(:input) { [File.new(input_path)] }
      let(:input_type) { "xsd" }

      it "calls Lutaml::Xsd" do
        allow(Lutaml::Xsd).to receive(:parse).once.and_call_original
        parse
        expect(Lutaml::Xsd).to have_received(:parse)
      end
    end
  end
end
