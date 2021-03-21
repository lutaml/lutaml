require "spec_helper"

RSpec.describe Lutaml::Parser do
  describe ".parse" do
    subject(:parse) { described_class.parse(input, input_type) }

    let(:input_type) { nil }

    context "when exp file supplied" do
      let(:input) { File.new(fixtures_path("test.exp")) }

      it "calls Lutaml::Express::Parsers::Exp" do
        # Expressir::ExpressExp::Cache.to_file(cache_file, repository, root_path: root_path)
        allow(Expressir::ExpressExp::Parser).to receive(:from_files)
        allow(Lutaml::Express::LutamlPath::DocumentWrapper).to receive(:new)
        parse
        expect(Expressir::ExpressExp::Parser).to have_received(:from_files)
      end
    end

    context 'when xmi file supplied' do
      let(:input) { File.new(fixtures_path("ea-xmi-2.4.2.xmi")) }

      it "calls Lutaml::Uml::Parsers::Dsl" do
        allow(Lutaml::XMI::Parsers::XML).to receive(:parse)
        allow(Lutaml::Uml::LutamlPath::DocumentWrapper).to receive(:new)
        parse
        expect(Lutaml::XMI::Parsers::XML).to have_received(:parse)
      end
    end

    context "when lutaml file supplied" do
      let(:input) { File.new(fixtures_path("test.lutaml")) }

      it "calls Lutaml::Uml::Parsers::Dsl" do
        allow(Lutaml::Uml::Parsers::Dsl).to receive(:parse)
        allow(Lutaml::Uml::LutamlPath::DocumentWrapper).to receive(:new)
        parse
        expect(Lutaml::Uml::Parsers::Dsl).to have_received(:parse)
      end
    end

    context "when exp cache yaml file supplied" do
      let(:input) { File.new(fixtures_path("test_exp_cached.yaml")) }
      let(:input_type) { "exp.cache" }

      it "calls Lutaml::Express::Parsers::Exp" do
        allow(Expressir::ExpressExp::Cache).to receive(:from_file).and_call_original
        allow(Lutaml::Express::LutamlPath::DocumentWrapper).to receive(:new).and_call_original
        parse
        expect(Expressir::ExpressExp::Cache).to have_received(:from_file)
      end
    end
  end
end
