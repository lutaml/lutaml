require "spec_helper"

RSpec.describe Lutaml::Parser do
  describe ".parse" do
    subject(:parse) { described_class.parse(input) }

    context "when exp file supplied" do
      let(:input) { File.new(fixtures_path("test.exp")) }

      it "calls Lutaml::Express::Parsers::Exp" do
        allow(Lutaml::Express::Parsers::Exp).to receive(:parse)
        allow(Lutaml::Express::LutamlPath::DocumentWrapper).to receive(:new)
        parse
        expect(Lutaml::Express::Parsers::Exp).to have_received(:parse)
      end
    end
  end
end
