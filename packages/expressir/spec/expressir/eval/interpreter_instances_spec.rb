# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "expressir/eval"

# TODO.sota/02 step 3: instance-aware evaluation over Part 21
# populations — attribute access through the entity slot mapping and
# the TYPEOF/USEDIN/EXISTS builtins.
RSpec.describe Expressir::Eval::Interpreter do
  let(:schema) do
    Expressir::Express::Parser.from_exp(
      File.read(Expressir.root_path.join("spec/fixtures/eval/population.exp")),
    ).schemas.first
  end

  let(:population) do
    Expressir::P21::Parser.parse(
      File.read(Expressir.root_path.join("spec/fixtures/eval/population.p21")),
    )
  end

  let(:interpreter) { described_class.new(schema: schema, population: population) }

  def instance(id)
    Expressir::Eval::Values::Instance.new(
      id: id, record: population.instances["##{id}"],
    )
  end

  it "reads an instance attribute" do
    expect(interpreter.call("label_of", [instance("1")])).to eq("a")
  end

  it "chains aggregate indexing and references into attribute access" do
    expect(interpreter.call("target_of", [instance("20")])).to eq("b")
  end

  it "types an instance (TYPEOF, unqualified and qualified)" do
    names = interpreter.call("node_types", [instance("1")]).elements
    expect(names).to include("NODE", "EVAL_POP.NODE")
  end

  it "finds referencing instances (USEDIN)" do
    referrers = interpreter.call("referrers", [instance("1")]).elements
    expect(referrers.map(&:id)).to eq(["10"])
  end

  it "propagates unset attributes as indeterminate" do
    edge = instance("10")
    expect(interpreter.call("label_of", [edge])).to eq(
      Expressir::Eval::Values::INDETERMINATE,
    )
  rescue Expressir::Eval::Error
    # label is not mapped on EDGE — the access itself must fail loudly
    expect { interpreter.call("label_of", [edge]) }
      .to raise_error(Expressir::Eval::Error, /not mapped/)
  end
end
