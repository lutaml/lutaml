# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.instance/04: ARM↔MIM instance mapping verification. A
# synthetic action-mapping module (the shape of the smallest shipped
# module mappings: an ARM entity mapped onto a MIM entity with
# attribute refpaths) with seeded divergences, each producing exactly
# the intended finding: a missing image and a name divergence breaking
# a constraint path; reference correspondence resolves through the
# person mapping, an alt_map route carries the directed_action image,
# and element rules gate matches (Eval WHERE semantics).
ARM_EXPRESS = <<~EXPRESS
  SCHEMA action_arm;
    ENTITY action;
      id : INTEGER;
      name : STRING;
    END_ENTITY;
    ENTITY change_request;
      name : STRING;
    END_ENTITY;
    ENTITY directed_action SUBTYPE OF (action);
      director : person;
    END_ENTITY;
    ENTITY person;
      name : STRING;
    END_ENTITY;
  END_SCHEMA;
EXPRESS

MIM_EXPRESS = <<~EXPRESS
  SCHEMA action_mim_schema;
    ENTITY action_mim;
      id : INTEGER;
      name : STRING;
    END_ENTITY;
    ENTITY directed_action_mim;
      assigned_action : action_mim;
      director : person_mim;
    END_ENTITY;
    ENTITY person_mim;
      name : STRING;
    END_ENTITY;
  END_SCHEMA;
EXPRESS

MAPPING_YAML = <<~YAML
  ae:
  - entity: action
    aimelt: <<express:action_mim_schema.action_mim,action_mim>>
    refpath:
      content: "action_mim"
    aa:
    - attribute: id
      aimelt: action_mim.id
      refpath:
        content: "action_mim.id"
    - attribute: name
      aimelt: action_mim.name
      refpath:
        content: "action_mim.name"
  - entity: change_request
    aimelt: <<express:action_mim_schema.action_mim,action_mim>>
    refpath:
      content: "action_mim {action_mim.name = 'cr9'}"
    aa:
    - attribute: name
      aimelt: action_mim.name
      refpath:
        content: "action_mim.name"
    rules:
      content: "id > 0"
  - entity: directed_action
    aimelt: <<express:action_mim_schema.action_mim,action_mim>>
    refpath:
      content: "action_mim"
    aa:
    - attribute: director
      aimelt: directed_action_mim.director
      refpath:
        content: "directed_action_mim.director -> person_mim"
    alt_map:
    - id: via_directed_action_mim
      aimelt: <<express:action_mim_schema.directed_action_mim,directed_action_mim>>
      refpath:
        content: "directed_action_mim.assigned_action -> action_mim"
  - entity: person
    aimelt: <<express:action_mim_schema.person_mim,person_mim>>
    refpath:
      content: "person_mim"
    aa:
    - attribute: name
      aimelt: person_mim.name
      refpath:
        content: "person_mim.name"
YAML

ARM_P21 = <<~P21
  ISO-10303-21;
  HEADER;
  FILE_NAME('arm.pop','2026-10-21T00:00:00',(''),(''),'','','');
  FILE_SCHEMA(('ACTION_ARM'));
  ENDSEC;
  DATA;
  #1=ACTION(1,'design');
  #2=CHANGE_REQUEST('cr9');
  #3=CHANGE_REQUEST('crX');
  #4=DIRECTED_ACTION(4,'rev',#10);
  #5=ACTION(5,'ghost');
  #6=ACTION(6,'crB');
  #10=PERSON('lee');
  ENDSEC;
  END-ISO-10303-21;
P21

# Seeded divergences against the ARM population: ARM #3's name never
# satisfies the change_request constraint path, and ARM #5 has no
# MIM image at all.
MIM_P21 = <<~P21
  ISO-10303-21;
  HEADER;
  FILE_NAME('mim.pop','2026-10-21T00:00:00',(''),'','','','');
  FILE_SCHEMA(('ACTION_MIM_SCHEMA'));
  ENDSEC;
  DATA;
  #1=ACTION_MIM(1,'design');
  #2=ACTION_MIM(2,'cr9');
  #3=ACTION_MIM(4,'rev');
  #4=DIRECTED_ACTION_MIM(#3,#5);
  #5=PERSON_MIM('lee');
  #6=ACTION_MIM(99,'unused');
  #7=ACTION_MIM(6,'crB');
  ENDSEC;
  END-ISO-10303-21;
P21

RSpec.describe Expressir::Mapping::InstanceVerification do
  def parse_express(text)
    Expressir::Express::Parser.from_exp(text).schemas.first
  end

  def parse_population(text)
    Expressir::P21::Parser.parse(text)
  end

  subject(:verification) do
    described_class.new(
      mapping: Expressir::Mapping::Document.from_yaml(MAPPING_YAML),
      arm_schema: arm_schema, mim_schema: mim_schema,
      arm_population: arm_population, mim_population: mim_population
    )
  end

  let(:arm_schema) { parse_express(ARM_EXPRESS) }
  let(:mim_schema) { parse_express(MIM_EXPRESS) }
  let(:arm_population) { parse_population(ARM_P21) }
  let(:mim_population) { parse_population(MIM_P21) }

  describe "#verify" do
    it "accepts every correctly mapped ARM instance" do
      findings = verification.verify
      divergent = %w[#3 #5]
      expect(findings.map(&:arm_instance) - divergent).to eq([])
    end

    it "reports the unmapped instance under the action element" do
      findings = verification.verify
      ghost = findings.find { |f| f.arm_instance == "#5" }
      expect(ghost.entity).to eq("action")
      expect(ghost.message).to include("no MIM image")
    end

    it "reports the constraint-path divergence under change_request" do
      findings = verification.verify
      divergent = findings.find { |f| f.arm_instance == "#3" }
      expect(divergent.entity).to eq("change_request")
    end

    it "reports exactly the seeded divergences" do
      findings = verification.verify
      expect(findings.count).to eq(2)
      expect(findings.map(&:arm_instance)).to eq(%w[#5 #3])
    end

    it "gates matches on rule predicates: an unsatisfiable element " \
       "rule unmasks every instance of that element" do
      gated = Expressir::Mapping::Document.from_yaml(
        MAPPING_YAML.sub('content: "id > 0"', 'content: "id < 0"'),
      )
      findings = described_class.new(
        mapping: gated, arm_schema: arm_schema, mim_schema: mim_schema,
        arm_population: arm_population, mim_population: mim_population
      ).verify
      expect(findings.map(&:arm_instance)).to include("#2")
      expect(findings.count { |f| f.entity == "change_request" }).to eq(2)
      expect(findings.count { |f| f.entity == "action" }).to eq(1)
    end

    it "resolves the directed_action image through its alt_map route " \
       "with the reference corresponding through the person mapping" do
      findings = verification.verify
      expect(findings.map(&:entity)).not_to include("directed_action")
      expect(findings.map(&:entity)).not_to include("person")
    end

    describe "mutation sweep: repairing one divergence removes only " \
             "its own finding" do
      def findings_with(arm: ARM_P21, mim: MIM_P21)
        described_class.new(
          mapping: Expressir::Mapping::Document.from_yaml(MAPPING_YAML),
          arm_schema: arm_schema, mim_schema: mim_schema,
          arm_population: parse_population(arm),
          mim_population: parse_population(mim)
        ).verify
      end

      it "images the ghost instance" do
        findings = findings_with(mim: MIM_P21.sub(
          "#6=ACTION_MIM(99,'unused');",
          "#6=ACTION_MIM(99,'unused');\n#8=ACTION_MIM(5,'ghost');",
        ))
        expect(findings.map(&:arm_instance)).to eq(%w[#3])
      end

      it "renames the constraint-divergent change_request" do
        findings = findings_with(arm: ARM_P21.sub(
          "#3=CHANGE_REQUEST('crX');", "#3=CHANGE_REQUEST('cr9');"
        ))
        expect(findings.map(&:arm_instance)).to eq(%w[#5])
      end
    end

    it "reports an element whose ARM entity the schema does not declare" do
      broken = Expressir::Mapping::Document.new(
        ae: [Expressir::Mapping::ApplicationElement.new(
          entity: "no_such_entity",
          aimelt: "<<express:action_mim_schema.action_mim,action_mim>>",
        )],
      )
      verify = described_class.new(
        mapping: broken, arm_schema: arm_schema, mim_schema: mim_schema,
        arm_population: arm_population, mim_population: mim_population
      )
      findings = verify.verify
      expect(findings.map(&:message))
        .to eq(["ARM schema declares no entity 'no_such_entity'"])
    end
  end
end
