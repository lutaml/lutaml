require "spec_helper"

RSpec.describe Lutaml::Parser do
  describe ".parse" do
    subject(:parse) { described_class.parse(input) }

    context "when exp file supplied" do
      let(:input) { File.new(fixtures_path("test.exp")) }

      it "calls Lutaml::Express::Parsers::Exp" do
        allow(Expressir::ExpressExp::Parser).to receive(:from_files)
        allow(Lutaml::Express::LutamlPath::DocumentWrapper).to receive(:new)
        parse
        expect(Expressir::ExpressExp::Parser).to have_received(:from_files)
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
  end
end
