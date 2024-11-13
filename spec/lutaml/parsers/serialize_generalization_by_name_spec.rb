require "spec_helper"

RSpec.describe Lutaml::XMI::Parsers::XML do
  describe ".serialize_generalization_by_name" do
    subject(:output) do
      described_class.serialize_generalization_by_name(file, path)
    end
    let(:file) { File.new(fixtures_path("plateau_all_packages_export.xmi")) }

    context "when parsing xmi" do
      context "with klass name only" do
        let(:path) { "_BoundarySurface" }
        include_examples "should output correct klass liquid drop",
                         "EAID_28A336C5_806D_4b20_80D6_D4EB0BB33335",
                         "_BoundarySurface"
      end

      context "with absolute path" do
        let(:path) do
          "::EA_Model::Conceptual Models::i-UR::" \
            "Urban Planning ADE 3.1::uro::_BoundarySurface"
        end
        include_examples "should output correct klass liquid drop",
                         "EAID_28A336C5_806D_4b20_80D6_D4EB0BB33335",
                         "_BoundarySurface"
      end

      context "with relative path" do
        let(:path) { "uro::_BoundarySurface" }
        include_examples "should output correct klass liquid drop",
                         "EAID_28A336C5_806D_4b20_80D6_D4EB0BB33335",
                         "_BoundarySurface"
      end
    end
  end
end
