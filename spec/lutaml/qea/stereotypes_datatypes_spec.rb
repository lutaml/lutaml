# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea"

RSpec.describe "Stereotypes and DataTypes Loading" do
  let(:qea_file) { "examples/qea/20251010_current_plateau_v5.1.qea" }
  let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_file) }
  let(:database) { loader.load }

  describe "Stereotypes" do
    it "loads stereotype definitions" do
      expect(database.stereotypes).not_to be_empty
      expect(database.stereotypes.size).to eq(155)
    end

    it "parses stereotype attributes correctly" do
      stereotype = database.stereotypes.first
      expect(stereotype).to be_a(Lutaml::Qea::Models::EaStereotype)
      expect(stereotype.stereotype).not_to be_nil
      expect(stereotype.applies_to).not_to be_nil
    end

    it "includes expected stereotype" do
      codelist = database.stereotypes.find do |s|
        s.stereotype == "CodeList"
      end
      expect(codelist).not_to be_nil
      expect(codelist.applies_to).to eq("Class")
    end

    it "has stereotype descriptions" do
      stereotypes_with_desc = database.stereotypes.select do |s|
        s.description && !s.description.empty?
      end
      expect(stereotypes_with_desc.size).to be > 140
    end

    it "groups stereotypes by applies_to" do
      by_type = database.stereotypes.group_by(&:applies_to)
      # Check that grouping works
      expect(by_type).not_to be_empty
      expect(by_type["Class"]).not_to be_nil
      expect(by_type["Class"].size).to be >= 5  # At least some Class stereotypes
      # Check for common meta-types
      all_types = by_type.keys
      expect(all_types).to include("Class")
    end
  end

  describe "Data Types" do
    it "loads data type definitions" do
      expect(database.datatypes).not_to be_empty
      expect(database.datatypes.size).to eq(630)
    end

    it "parses datatype attributes correctly" do
      datatype = database.datatypes.first
      expect(datatype).to be_a(Lutaml::Qea::Models::EaDatatype)
      expect(datatype.type).not_to be_nil
      expect(datatype.data_type).not_to be_nil
    end

    it "includes DDL types" do
      ddl_types = database.datatypes.select(&:ddl_type?)
      expect(ddl_types.size).to be > 500
    end

    it "includes Code types" do
      code_types = database.datatypes.select(&:code_type?)
      expect(code_types.size).to be > 80
    end

    it "maps database vendor types" do
      oracle_types = database.datatypes.select do |dt|
        dt.product_name == "Oracle"
      end
      expect(oracle_types.size).to be > 50

      varchar2 = oracle_types.find { |dt| dt.data_type == "VARCHAR2" }
      expect(varchar2).not_to be_nil
      expect(varchar2.generic_type).to eq("varchar")
    end

    it "handles type size information" do
      sized_types = database.datatypes.select(&:has_length?)
      expect(sized_types).not_to be_empty

      precision_types = database.datatypes.select(&:has_precision?)
      expect(precision_types).not_to be_empty
    end

    it "generates type signatures" do
      char_type = database.datatypes.find do |dt|
        dt.data_type == "CHAR" && dt.has_length?
      end
      expect(char_type).not_to be_nil
      expect(char_type.type_signature).to match(/CHAR\(\d+\)/)
    end
  end

  describe "Database statistics" do
    it "includes stereotypes and datatypes in stats" do
      stats = database.stats
      expect(stats["stereotypes"]).to eq(155)
      expect(stats["datatypes"]).to eq(630)
    end

    it "includes them in total records" do
      total = database.total_records
      expect(total).to be > 785  # At least stereotypes + datatypes
    end
  end

  describe "Integration with existing data" do
    it "stereotypes are available as reference data" do
      # Stereotypes from t_stereotype table should be available
      # for lookup when processing objects with stereotypes
      stereotype_names = database.stereotypes.map(&:stereotype)
      expect(stereotype_names).to include("CodeList")

      # Objects can reference these stereotypes
      classes = database.objects.find_by_type("Class")
      classes_with_stereotypes = classes.select do |cls|
        cls.stereotype && !cls.stereotype.empty?
      end

      expect(classes_with_stereotypes).not_to be_empty
    end

    it "datatypes are available as reference data" do
      # DataTypes table provides metadata for type resolution
      # It doesn't directly map to UML attribute types, but provides
      # reference information for database schema generation
      expect(database.datatypes).not_to be_empty

      # Attributes have types that may or may not be in datatypes table
      attrs_with_types = database.attributes.select do |attr|
        attr.type && !attr.type.empty?
      end
      expect(attrs_with_types).not_to be_empty
    end
  end
end