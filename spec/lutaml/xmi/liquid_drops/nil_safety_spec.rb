# frozen_string_literal: true

require "spec_helper"
require "lutaml/xmi/liquid_drops/root_drop"
require "lutaml/xmi/liquid_drops/package_drop"
require "lutaml/xmi/liquid_drops/klass_drop"
require "lutaml/xmi/liquid_drops/data_type_drop"
require "lutaml/xmi/liquid_drops/enum_drop"

# Minimal stub models whose collection accessors return nil (simulating
# lutaml-model objects without defaults set).
module NilModelStubs
  class NilClassModel
    def xmi_id = "xmi_id_1"
    def name = "TestClass"
    def type = "uml:Class"
    def is_abstract = false
    def definition = nil
    def stereotype = nil
    def attributes = nil
    def operations = nil
    def constraints = nil
    def associations = nil
    def generalization = nil
  end

  class NilDataTypeModel
    def xmi_id = "xmi_id_2"
    def name = "TestDataType"
    def is_abstract = false
    def definition = nil
    def stereotype = nil
    def attributes = nil
    def operations = nil
    def constraints = nil
    def associations = nil
  end

  class NilEnumModel
    def xmi_id = "xmi_id_3"
    def name = "TestEnum"
    def definition = nil
    def stereotype = nil
    def values = nil
  end

  class NilPackageModel
    def xmi_id = "xmi_id_4"
    def name = "TestPackage"
    def definition = nil
    def stereotype = nil
    def classes = nil
    def enums = nil
    def data_types = nil
    def diagrams = nil
    def packages = nil
    def children_packages = nil
  end

  class NilRootModel
    def name = "TestRoot"
    def packages = nil
  end

  class StubLookup
    def select_dependencies_by_supplier(*) = []
    def select_dependencies_by_client(*) = []
    def find_matched_element(*) = nil
    def find_upper_level_packaged_element(*) = nil
  end

  def self.stub_options
    { lookup: StubLookup.new, xmi_root_model: nil, id_name_mapping: {} }
  end
end

RSpec.describe "XMI Liquid Drops nil-safety" do
  describe Lutaml::Xmi::LiquidDrops::KlassDrop do
    subject(:drop) do
      described_class.new(NilModelStubs::NilClassModel.new, nil,
                          NilModelStubs.stub_options)
    end

    it "returns empty array for attributes when model returns nil" do
      expect(drop.attributes).to eq([])
    end

    it "returns empty array for owned_attributes when model returns nil" do
      expect(drop.owned_attributes).to eq([])
    end

    it "returns empty array for associations when model returns nil" do
      expect(drop.associations).to eq([])
    end

    it "returns empty array for operations when model returns nil" do
      expect(drop.operations).to eq([])
    end

    it "returns empty array for constraints when model returns nil" do
      expect(drop.constraints).to eq([])
    end
  end

  describe Lutaml::Xmi::LiquidDrops::DataTypeDrop do
    subject(:drop) do
      described_class.new(NilModelStubs::NilDataTypeModel.new,
                          NilModelStubs.stub_options)
    end

    it "returns empty array for attributes when model returns nil" do
      expect(drop.attributes).to eq([])
    end

    it "returns empty array for associations when model returns nil" do
      expect(drop.associations).to eq([])
    end

    it "returns empty array for operations when model returns nil" do
      expect(drop.operations).to eq([])
    end

    it "returns empty array for constraints when model returns nil" do
      expect(drop.constraints).to eq([])
    end
  end

  describe Lutaml::Xmi::LiquidDrops::EnumDrop do
    subject(:drop) do
      described_class.new(NilModelStubs::NilEnumModel.new,
                          NilModelStubs.stub_options)
    end

    it "returns empty array for values when model returns nil" do
      expect(drop.values).to eq([])
    end
  end

  describe Lutaml::Xmi::LiquidDrops::PackageDrop do
    subject(:drop) do
      described_class.new(NilModelStubs::NilPackageModel.new, nil,
                          NilModelStubs.stub_options)
    end

    it "returns empty array for classes when model returns nil" do
      expect(drop.classes).to eq([])
    end

    it "returns empty array for enums when model returns nil" do
      expect(drop.enums).to eq([])
    end

    it "returns empty array for data_types when model returns nil" do
      expect(drop.data_types).to eq([])
    end

    it "returns empty array for diagrams when model returns nil" do
      expect(drop.diagrams).to eq([])
    end

    it "returns empty array for packages when model returns nil" do
      expect(drop.packages).to eq([])
    end

    it "returns empty array for children_packages when model returns nil" do
      expect(drop.children_packages).to eq([])
    end
  end

  describe Lutaml::Xmi::LiquidDrops::RootDrop do
    subject(:drop) do
      described_class.new(NilModelStubs::NilRootModel.new, nil,
                          NilModelStubs.stub_options)
    end

    it "returns empty array for packages when model returns nil" do
      expect(drop.packages).to eq([])
    end

    it "returns empty array for children_packages when model returns nil" do
      expect(drop.children_packages).to eq([])
    end
  end
end
