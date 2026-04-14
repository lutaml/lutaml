# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea"

RSpec.describe "Priority 3 Lookup Tables" do
  let(:qea_file) do
    File.join(__dir__,
              "../../../examples/qea/20251010_current_plateau_v5.1.qea")
  end
  let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_file) }
  let(:database) { loader.load }

  describe "Constraint Types" do
    let(:constraint_types) { database.constraint_types }

    it "loads constraint types from database" do
      expect(constraint_types).not_to be_empty
      expect(constraint_types.size).to eq(4)
    end

    it "has correct structure" do
      constraint_type = constraint_types.first
      expect(constraint_type).to be_a(Lutaml::Qea::Models::EaConstraintType)
      expect(constraint_type).to respond_to(:constraint)
      expect(constraint_type).to respond_to(:description)
      expect(constraint_type).to respond_to(:notes)
    end

    it "includes Invariant type" do
      invariant = constraint_types.find { |ct| ct.constraint == "Invariant" }
      expect(invariant).not_to be_nil
      expect(invariant.description).to include("state")
      expect(invariant.invariant?).to be true
    end

    it "includes Pre-condition type" do
      precondition = constraint_types.find do |ct|
        ct.constraint == "Pre-condition"
      end
      expect(precondition).not_to be_nil
      expect(precondition.precondition?).to be true
    end

    it "includes Post-condition type" do
      postcondition = constraint_types.find do |ct|
        ct.constraint == "Post-condition"
      end
      expect(postcondition).not_to be_nil
      expect(postcondition.postcondition?).to be true
    end

    it "includes Process type" do
      process = constraint_types.find { |ct| ct.constraint == "Process" }
      expect(process).not_to be_nil
      expect(process.process?).to be true
    end

    it "provides name accessor" do
      constraint_type = constraint_types.first
      expect(constraint_type.name).to eq(constraint_type.constraint)
    end
  end

  describe "Connector Types" do
    let(:connector_types) { database.connector_types }

    it "loads connector types from database" do
      expect(connector_types).not_to be_empty
      expect(connector_types.size).to eq(30)
    end

    it "has correct structure" do
      connector_type = connector_types.first
      expect(connector_type).to be_a(Lutaml::Qea::Models::EaConnectorType)
      expect(connector_type).to respond_to(:connector_type)
      expect(connector_type).to respond_to(:description)
    end

    it "includes Association type" do
      association = connector_types.find do |ct|
        ct.connector_type == "Association"
      end
      expect(association).not_to be_nil
      expect(association.association?).to be true
    end

    it "includes Generalization type" do
      generalization = connector_types.find do |ct|
        ct.connector_type == "Generalization"
      end
      expect(generalization).not_to be_nil
      expect(generalization.generalization?).to be true
    end

    it "includes Aggregation type" do
      aggregation = connector_types.find do |ct|
        ct.connector_type == "Aggregation"
      end
      expect(aggregation).not_to be_nil
      expect(aggregation.aggregation?).to be true
    end

    it "includes Dependency type" do
      dependency = connector_types.find do |ct|
        ct.connector_type == "Dependency"
      end
      expect(dependency).not_to be_nil
      expect(dependency.dependency?).to be true
    end

    it "provides name accessor" do
      connector_type = connector_types.first
      expect(connector_type.name).to eq(connector_type.connector_type)
    end
  end

  describe "Diagram Types" do
    let(:diagram_types) { database.diagram_types }

    it "loads diagram types from database" do
      expect(diagram_types).not_to be_empty
      expect(diagram_types.size).to eq(15)
    end

    it "has correct structure" do
      diagram_type = diagram_types.first
      expect(diagram_type).to be_a(Lutaml::Qea::Models::EaDiagramType)
      expect(diagram_type).to respond_to(:diagram_type)
      expect(diagram_type).to respond_to(:name)
      expect(diagram_type).to respond_to(:package_id)
    end

    it "includes Logical (class diagram) type" do
      logical = diagram_types.find { |dt| dt.diagram_type == "Logical" }
      expect(logical).not_to be_nil
      expect(logical.name).to eq("Logical View")
      expect(logical.class_diagram?).to be true
    end

    it "includes Activity diagram type" do
      activity = diagram_types.find { |dt| dt.diagram_type == "Activity" }
      expect(activity).not_to be_nil
      expect(activity.activity_diagram?).to be true
    end

    it "includes Component diagram type" do
      component = diagram_types.find { |dt| dt.diagram_type == "Component" }
      expect(component).not_to be_nil
    end

    it "provides type_name accessor" do
      diagram_type = diagram_types.first
      expect(diagram_type.type_name).to eq(diagram_type.diagram_type)
    end
  end

  describe "Object Types" do
    let(:object_types) { database.object_types }

    it "loads object types from database" do
      expect(object_types).not_to be_empty
      expect(object_types.size).to eq(80)
    end

    it "has correct structure" do
      object_type = object_types.first
      expect(object_type).to be_a(Lutaml::Qea::Models::EaObjectType)
      expect(object_type).to respond_to(:object_type)
      expect(object_type).to respond_to(:description)
      expect(object_type).to respond_to(:designobject)
      expect(object_type).to respond_to(:imageid)
    end

    it "includes Class type" do
      klass = object_types.find { |ot| ot.object_type == "Class" }
      expect(klass).not_to be_nil
      expect(klass.class_type?).to be true
    end

    it "includes Interface type" do
      interface = object_types.find { |ot| ot.object_type == "Interface" }
      expect(interface).not_to be_nil
      expect(interface.interface_type?).to be true
    end

    it "includes Package type" do
      package = object_types.find { |ot| ot.object_type == "Package" }
      expect(package).not_to be_nil
      expect(package.package_type?).to be true
    end

    it "includes Actor type" do
      actor = object_types.find { |ot| ot.object_type == "Actor" }
      expect(actor).not_to be_nil
      expect(actor.actor_type?).to be true
    end

    it "provides design_object? method" do
      object_type = object_types.first
      expect(object_type).to respond_to(:design_object?)
    end

    it "provides readable aliases" do
      object_type = object_types.first
      expect(object_type.design_object).to eq(object_type.designobject)
      expect(object_type.image_id).to eq(object_type.imageid)
    end

    it "provides name accessor" do
      object_type = object_types.first
      expect(object_type.name).to eq(object_type.object_type)
    end
  end

  describe "Status Types" do
    let(:status_types) { database.status_types }

    it "loads status types from database" do
      expect(status_types).not_to be_empty
      expect(status_types.size).to eq(5)
    end

    it "has correct structure" do
      status_type = status_types.first
      expect(status_type).to be_a(Lutaml::Qea::Models::EaStatusType)
      expect(status_type).to respond_to(:status)
      expect(status_type).to respond_to(:description)
    end

    it "includes Approved status" do
      approved = status_types.find { |st| st.status == "Approved" }
      expect(approved).not_to be_nil
      expect(approved.description).to include("approved")
      expect(approved.approved?).to be true
    end

    it "includes Implemented status" do
      implemented = status_types.find { |st| st.status == "Implemented" }
      expect(implemented).not_to be_nil
      expect(implemented.implemented?).to be true
    end

    it "includes Mandatory status" do
      mandatory = status_types.find { |st| st.status == "Mandatory" }
      expect(mandatory).not_to be_nil
      expect(mandatory.mandatory?).to be true
    end

    it "includes Proposed status" do
      proposed = status_types.find { |st| st.status == "Proposed" }
      expect(proposed).not_to be_nil
      expect(proposed.proposed?).to be true
    end

    it "includes Validated status" do
      validated = status_types.find { |st| st.status == "Validated" }
      expect(validated).not_to be_nil
      expect(validated.validated?).to be true
    end

    it "provides name accessor" do
      status_type = status_types.first
      expect(status_type.name).to eq(status_type.status)
    end
  end

  describe "Complexity Types" do
    let(:complexity_types) { database.complexity_types }

    it "loads complexity types from database" do
      expect(complexity_types).not_to be_empty
      expect(complexity_types.size).to eq(6)
    end

    it "has correct structure" do
      complexity_type = complexity_types.first
      expect(complexity_type).to be_a(Lutaml::Qea::Models::EaComplexityType)
      expect(complexity_type).to respond_to(:complexity)
      expect(complexity_type).to respond_to(:numericweight)
    end

    it "includes all complexity levels" do
      names = complexity_types.map(&:complexity)
      expect(names).to include("V.Low", "Low", "Medium", "High", "V.High",
                               "Extreme")
    end

    it "has correct numeric weights" do
      extreme = complexity_types.find { |ct| ct.complexity == "Extreme" }
      expect(extreme.numeric_weight).to eq(6)

      high = complexity_types.find { |ct| ct.complexity == "High" }
      expect(high.numeric_weight).to eq(4)

      low = complexity_types.find { |ct| ct.complexity == "Low" }
      expect(low.numeric_weight).to eq(2)
    end

    it "provides low? checker" do
      vlow = complexity_types.find { |ct| ct.complexity == "V.Low" }
      low = complexity_types.find { |ct| ct.complexity == "Low" }
      medium = complexity_types.find { |ct| ct.complexity == "Medium" }

      expect(vlow.low?).to be true
      expect(low.low?).to be true
      expect(medium.low?).to be false
    end

    it "provides high? checker" do
      vhigh = complexity_types.find { |ct| ct.complexity == "V.High" }
      high = complexity_types.find { |ct| ct.complexity == "High" }
      medium = complexity_types.find { |ct| ct.complexity == "Medium" }

      expect(vhigh.high?).to be true
      expect(high.high?).to be true
      expect(medium.high?).to be false
    end

    it "provides medium? and extreme? checkers" do
      medium = complexity_types.find { |ct| ct.complexity == "Medium" }
      extreme = complexity_types.find { |ct| ct.complexity == "Extreme" }

      expect(medium.medium?).to be true
      expect(extreme.extreme?).to be true
    end

    it "provides weight accessor" do
      complexity_type = complexity_types.first
      expect(complexity_type.weight).to eq(complexity_type.numericweight)
    end

    it "provides readable alias" do
      complexity_type = complexity_types.first
      expect(complexity_type.numeric_weight)
        .to eq(complexity_type.numericweight)
    end

    it "supports comparison by weight" do
      low = complexity_types.find { |ct| ct.complexity == "Low" }
      high = complexity_types.find { |ct| ct.complexity == "High" }
      extreme = complexity_types.find { |ct| ct.complexity == "Extreme" }

      expect(low <=> high).to eq(-1)
      expect(high <=> low).to eq(1)
      expect(high <=> high).to eq(0)
      expect(extreme <=> high).to eq(1)
    end
  end

  describe "Database Statistics" do
    it "includes all lookup tables in stats" do
      stats = database.stats
      expect(stats).to include("constraint_types")
      expect(stats).to include("connector_types")
      expect(stats).to include("diagram_types")
      expect(stats).to include("object_types")
      expect(stats).to include("status_types")
      expect(stats).to include("complexity_types")
    end

    it "reports correct counts" do
      stats = database.stats
      expect(stats["constraint_types"]).to eq(4)
      expect(stats["connector_types"]).to eq(30)
      expect(stats["diagram_types"]).to eq(15)
      expect(stats["object_types"]).to eq(80)
      expect(stats["status_types"]).to eq(5)
      expect(stats["complexity_types"]).to eq(6)
    end

    it "totals 140 lookup table records" do
      lookup_total = database.constraint_types.size +
        database.connector_types.size +
        database.diagram_types.size +
        database.object_types.size +
        database.status_types.size +
        database.complexity_types.size
      expect(lookup_total).to eq(140)
    end
  end
end
