# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_object_constraint"

RSpec.describe Lutaml::Qea::Models::EaObjectConstraint do
  describe ".from_db_row" do
    it "creates constraint from database row with all fields" do
      row = {
        "ConstraintID" => 1,
        "Object_ID" => 4,
        "Constraint" => "count(self.legalConstraints.accessConstraints) >= 1",
        "ConstraintType" => "Invariant",
        "Weight" => "0.0",
        "Notes" => "Test note",
        "Status" => "Approved"
      }

      constraint = described_class.from_db_row(row)

      expect(constraint.constraint_id).to eq(1)
      expect(constraint.object_id).to eq(4)
      expect(constraint.constraint).to include("legalConstraints")
      expect(constraint.constraint_type).to eq("Invariant")
      expect(constraint.weight).to eq(0.0)
      expect(constraint.notes).to eq("Test note")
      expect(constraint.status).to eq("Approved")
    end

    it "creates constraint with nil optional fields" do
      row = {
        "ConstraintID" => 2,
        "Object_ID" => 5,
        "Constraint" => "crs -> size() = 1 implies fixed = true",
        "ConstraintType" => "Invariant",
        "Weight" => "10000.0",
        "Notes" => nil,
        "Status" => "Approved"
      }

      constraint = described_class.from_db_row(row)

      expect(constraint.constraint_id).to eq(2)
      expect(constraint.object_id).to eq(5)
      expect(constraint.constraint).to include("crs")
      expect(constraint.weight).to eq(10000.0)
      expect(constraint.notes).to be_nil
    end

    it "returns nil for nil row" do
      expect(described_class.from_db_row(nil)).to be_nil
    end

    it "handles nil weight" do
      row = {
        "ConstraintID" => 3,
        "Object_ID" => 9,
        "Constraint" => "count(self.version) >= 1",
        "ConstraintType" => "Invariant",
        "Weight" => nil,
        "Notes" => nil,
        "Status" => "Approved"
      }

      constraint = described_class.from_db_row(row)

      expect(constraint.weight).to be_nil
    end
  end

  describe ".table_name" do
    it "returns correct table name" do
      expect(described_class.table_name).to eq("t_objectconstraint")
    end
  end

  describe ".primary_key_column" do
    it "returns correct primary key column" do
      expect(described_class.primary_key_column).to eq(:constraint_id)
    end
  end
end