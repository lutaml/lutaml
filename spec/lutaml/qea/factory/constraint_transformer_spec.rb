# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/constraint_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_object_constraint"
require_relative "../../../../lib/lutaml/qea/database"

RSpec.describe Lutaml::Qea::Factory::ConstraintTransformer do
  let(:database) { instance_double(Lutaml::Qea::Database) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "transforms EA constraint to UML Constraint" do
      ea_constraint = Lutaml::Qea::Models::EaObjectConstraint.new(
        constraint_id: 1,
        object_id: 4,
        constraint: "count(self.legalConstraints.accessConstraints) >= 1",
        constraint_type: "Invariant",
        weight: 0.0,
        notes: nil,
        status: "Approved",
      )

      uml_constraint = transformer.transform(ea_constraint)

      expect(uml_constraint).to be_a(Lutaml::Uml::Constraint)
      expect(uml_constraint.xmi_id).to eq("constraint_1")
      expect(uml_constraint.body).to include("legalConstraints")
      expect(uml_constraint.type).to eq("Invariant")
      expect(uml_constraint.weight).to eq("0.0")
      expect(uml_constraint.status).to eq("Approved")
    end

    it "generates name from constraint body" do
      ea_constraint = Lutaml::Qea::Models::EaObjectConstraint.new(
        constraint_id: 2,
        object_id: 5,
        constraint: "count(self.version) >= 1",
        constraint_type: "Invariant",
        weight: 0.0,
        status: "Approved",
      )

      uml_constraint = transformer.transform(ea_constraint)

      expect(uml_constraint.name).to eq("count")
    end

    it "handles constraint with special characters in body" do
      ea_constraint = Lutaml::Qea::Models::EaObjectConstraint.new(
        constraint_id: 3,
        object_id: 5,
        constraint: "crs -> size() = 1 implies fixed = true",
        constraint_type: "Invariant",
        weight: 10000.0,
        status: "Approved",
      )

      uml_constraint = transformer.transform(ea_constraint)

      expect(uml_constraint.name).to eq("crs")
      expect(uml_constraint.weight).to eq("10000.0")
    end

    it "returns nil for nil constraint" do
      expect(transformer.transform(nil)).to be_nil
    end

    it "handles constraint with nil weight" do
      ea_constraint = Lutaml::Qea::Models::EaObjectConstraint.new(
        constraint_id: 4,
        object_id: 9,
        constraint: "count(self.dateOfLastChange) >= 1",
        constraint_type: "Invariant",
        weight: nil,
        status: "Approved",
      )

      uml_constraint = transformer.transform(ea_constraint)

      expect(uml_constraint.weight).to be_nil
    end

    it "uses constraint_id as fallback name when body is empty" do
      ea_constraint = Lutaml::Qea::Models::EaObjectConstraint.new(
        constraint_id: 5,
        object_id: 10,
        constraint: "",
        constraint_type: "Invariant",
        weight: 0.0,
        status: "Approved",
      )

      uml_constraint = transformer.transform(ea_constraint)

      expect(uml_constraint.name).to eq("constraint_5")
    end
  end

  describe "#transform_collection" do
    it "transforms multiple constraints" do
      ea_constraints = [
        Lutaml::Qea::Models::EaObjectConstraint.new(
          constraint_id: 1,
          object_id: 4,
          constraint: "count(self.legalConstraints) >= 1",
          constraint_type: "Invariant",
          weight: 0.0,
          status: "Approved",
        ),
        Lutaml::Qea::Models::EaObjectConstraint.new(
          constraint_id: 2,
          object_id: 5,
          constraint: "crs -> size() = 1",
          constraint_type: "Invariant",
          weight: 10000.0,
          status: "Approved",
        ),
      ]

      uml_constraints = transformer.transform_collection(ea_constraints)

      expect(uml_constraints.size).to eq(2)
      expect(uml_constraints.first).to be_a(Lutaml::Uml::Constraint)
      expect(uml_constraints.last).to be_a(Lutaml::Uml::Constraint)
    end

    it "returns empty array for nil collection" do
      expect(transformer.transform_collection(nil)).to eq([])
    end

    it "returns empty array for empty collection" do
      expect(transformer.transform_collection([])).to eq([])
    end
  end
end
