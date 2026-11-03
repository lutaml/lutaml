# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.p28/02: the uos reader inverts the writer's default-binding
# encodings so parse(emit(population)) is value-identical at the
# record level, with logical faces resolved through the declared
# EXPRESS types.
RSpec.describe Expressir::P28::Uos do
  def parse_express(text)
    Expressir::Express::Parser.from_exp(text).schemas.first
  end

  def parse_population(text)
    Expressir::P21::Parser.parse(text)
  end

  def canonical(population)
    population.instances.to_h do |pid, record|
      values = record.is_a?(Expressir::P21::ComplexRecord) ? record : record.params
      [pid, values]
    end
  end

  describe "#parse" do
    let(:schema) do
      parse_express(<<~EXPRESS)
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

    it "reads the hand-written clause 9.2.6.1 worked example" do
      xml = <<~XML
        <uos id="expdata01" express="car_ownership"
            xmlns:own="URN:my_company.com:iso_10303_28/Car_ownership"
            xmlns:exp="urn:iso:std:iso:10303:-28:ed-2:tech:XMLschema:common">
          <own:Person id="id10">
            <Name>John Q. Public</Name>
            <Owns ref="id20"/>
          </own:Person>
          <own:Car id="id20">
            <Make>BMW</Make>
            <Car_model>Z3</Car_model>
          </own:Car>
        </uos>
      XML
      population = described_class.parse(xml, schema)
      person = population.instances["#10"]
      expect(person.keyword).to eq("PERSON")
      expect(person.params).to eq(["John Q. Public", "#20"])
      expect(population.instances["#20"].params).to eq(["BMW", "Z3"])
    end

    it "round-trips the writer's value matrix value-identically" do
      values_schema = parse_express(<<~EXPRESS)
        SCHEMA values_demo;
          TYPE colour = ENUMERATION OF (red, green);
        END_TYPE;
          ENTITY box;
            label : STRING;
            count : INTEGER;
            ratio : REAL;
            flag : BOOLEAN;
            state : LOGICAL;
            hue : colour;
            bits : BINARY;
            tags : LIST [1:?] OF STRING;
            parts : LIST [1:?] OF widget;
          END_ENTITY;
          ENTITY widget;
            code : INTEGER;
          END_ENTITY;
        END_SCHEMA;
      EXPRESS
      population = parse_population(<<~P21)
        ISO-10303-21;
        HEADER;
        FILE_NAME('v.pop','2026-10-22T00:00:00',(''),'','','','');
        FILE_SCHEMA(('VALUES_DEMO'));
        ENDSEC;
        DATA;
        #1=BOX('bin',7,2.5,.T.,.UNKNOWN.,.green.,"0AFF",('a','b'),(#2));
        #2=WIDGET(9);
        ENDSEC;
        END-ISO-10303-21;
      P21
      emitted = described_class.emit(
        population, values_schema,
        target_namespace: "URN:t:values_demo", prefix: "vd"
      )
      parsed = described_class.parse(emitted, values_schema)
      expect(canonical(parsed)).to eq(canonical(population))
    end

    it "round-trips complex entities and $ slots value-identically" do
      pair_schema = parse_express(<<~EXPRESS)
        SCHEMA pair_demo;
          ENTITY base_a;
            shared : INTEGER;
            extra : OPTIONAL STRING;
          END_ENTITY;
          ENTITY base_b;
            extra : STRING;
          END_ENTITY;
        END_SCHEMA;
      EXPRESS
      population = parse_population(<<~P21)
        ISO-10303-21;
        HEADER;
        FILE_NAME('c.pop','2026-10-22T00:00:00',(''),'','','','');
        FILE_SCHEMA(('PAIR_DEMO'));
        ENDSEC;
        DATA;
        #1=(BASE_A(3,$)BASE_B('x'));
        ENDSEC;
        END-ISO-10303-21;
      P21
      emitted = described_class.emit(
        population, pair_schema,
        target_namespace: "URN:t:pair", prefix: "pd"
      )
      parsed = described_class.parse(emitted, pair_schema)
      expect(canonical(parsed)).to eq(canonical(population))
    end

    it "rejects an element that matches no entity" do
      xml = <<~XML
        <uos id="u" express="car_ownership"
            xmlns:exp="urn:iso:std:iso:10303:-28:ed-2:tech:XMLschema:common">
          <own:Blob id="id1"/>
        </uos>
      XML
      expect { described_class.parse(xml, schema) }
        .to raise_error(Expressir::Error, /does not match any entity/)
    end

    describe "mutation sweep: one flipped value is exactly one " \
             "parameter difference" do
      let(:population) do
        parse_population(<<~P21)
          ISO-10303-21;
          HEADER;
          FILE_NAME('m.pop','2026-10-22T00:00:00',(''),'','','','');
          FILE_SCHEMA(('CAR_OWNERSHIP'));
          ENDSEC;
          DATA;
          #10=PERSON('John Q. Public',#20);
          #20=CAR('BMW','Z3');
          ENDSEC;
          END-ISO-10303-21;
        P21
      end

      it "detects a changed attribute text" do
        emitted = described_class.emit(
          population, schema, target_namespace: "URN:t:co", prefix: "own"
        )
        mutated = emitted.sub("<Make>BMW</Make>", "<Make>AUDI</Make>")
        parsed = described_class.parse(mutated, schema)
        expect(canonical(parsed)["#20"].first).to eq("AUDI")
        expect(canonical(parsed)["#20"][1]).to eq("Z3")
        expect(canonical(parsed)["#10"]).to eq(canonical(population)["#10"])
      end

      it "detects a changed reference" do
        emitted = described_class.emit(
          population, schema, target_namespace: "URN:t:co", prefix: "own"
        )
        mutated = emitted.sub('ref="id20"', 'ref="id99"')
        parsed = described_class.parse(mutated, schema)
        expect(canonical(parsed)["#10"].last).to eq("#99")
      end
    end
  end
end
