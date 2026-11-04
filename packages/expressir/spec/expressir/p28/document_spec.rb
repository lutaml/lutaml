# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.p28/04: the iso_10303_28 envelope (clause 9.2.1/9.2.3/9.2.6.2).
# The static children are lutaml-model Serializables; the uos
# content stays P28::Uos. Round trip: express sources and populations
# come back value-identical.
RSpec.describe Expressir::P28::Document do
  subject(:document) do
    described_class.emit(express: [express], units: [unit])
  end

  let(:schema_source) do
    <<~EXPRESS
      SCHEMA car_ownership;
        ENTITY person;
          name : STRING;
          owns : car;
        END_ENTITY;
        ENTITY car;
          make : STRING;
          car_model : STRING;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  let(:schema) do
    Expressir::Express::Parser.from_exp(schema_source).schemas.first
  end

  let(:population) do
    Expressir::P21::Parser.parse(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('p.stp','2026-10-22T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('CAR_OWNERSHIP'));
      ENDSEC;
      DATA;
      #10=PERSON('John Q. Public',#20);
      #20=CAR('BMW','Z3');
      ENDSEC;
      END-ISO-10303-21;
    P21
  end

  let(:unit) do
    Expressir::P28::Uos.emit(
      population, schema, id: "expdata01", schema_ref: "exp01",
                          target_namespace: "URN:my_company.com:iso_10303_28/Car_ownership",
                          prefix: "own"
    )
  end

  let(:express) do
    described_class::ExpressElement.new(
      id: "exp01", schema_name: "car_ownership", source: schema_source,
    )
  end

  it "emits the clause 9.2.6.1 envelope shape" do
    expect(document).to include("<iso_10303_28")
    expect(document).to include('<express id="exp01"')
    expect(document).to include('schema_name="car_ownership"')
    expect(document).to include("SCHEMA car_ownership;")
    expect(document).to include("<own:uos")
    expect(document).to include("<own:Person")
  end

  it "round-trips express sources and populations value-identically" do
    parsed = described_class.parse(document)
    expect(parsed[:express].first.id).to eq("exp01")
    expect(parsed[:express].first.schema_name).to eq("car_ownership")
    expect(parsed[:express].first.source).to include("SCHEMA car_ownership;")
    expect(parsed[:schemas].keys).to eq(["exp01"])

    instances = parsed[:units]["exp01"].instances
    expect(instances["#10"].params).to eq(["John Q. Public", "#20"])
    expect(instances["#20"].params).to eq(["BMW", "Z3"])
  end

  it "carries the document header when present" do
    header = described_class::Header.new(
      name: "p.stp", time_stamp: "2026-10-22T00:00:00",
      author: ["a"], authorization: "z"
    )
    with_header = described_class.emit(express: [express], units: [unit],
                                       header: header)
    expect(with_header).to include("<name>p.stp</name>")
    expect(with_header).to include("<authorization>z</authorization>")
    parsed = described_class.parse(with_header)
    expect(parsed[:express].first.id).to eq("exp01")
  end

  it "rejects a uos referencing an unknown express id" do
    broken = document.sub('schema="exp01"', 'schema="other"')
    expect { described_class.parse(broken) }
      .to raise_error(Expressir::Error, /unknown express id/)
  end
end
