# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.p28/01: the uos writer against the clause 9.2.6.1 worked
# example (car ownership): by-value entity instance elements named
# per the 8.5.5 identifier conversion, attribute accessors unprefixed,
# references by `ref` (9.3.3), enumeration items as text (9.6.1).
RSpec.describe Expressir::P28::Uos do
  def parse_express(text)
    Expressir::Express::Parser.from_exp(text).schemas.first
  end

  def parse_population(text)
    Expressir::P21::Parser.parse(text)
  end

  def elems(node)
    node.children.grep(Moxml::Element)
  end

  def find_elem(node, name)
    elems(node).find { |c| c.name == name }
  end

  def attrs(node)
    node.attributes.to_h { |a| [a.name, a.value] }
  end

  subject(:emitted) do
    described_class.emit(population, schema, id: "expdata01",
                                             prefix: "own")
  end

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

  let(:population) do
    parse_population(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('p21.pop','2026-10-22T00:00:00',(''),(''),'','','');
      FILE_SCHEMA(('CAR_OWNERSHIP'));
      ENDSEC;
      DATA;
      #10=PERSON('John Q. Public',#20);
      #20=CAR('BMW','Z3');
      ENDSEC;
      END-ISO-10303-21;
    P21
  end

  it "reproduces the clause 9.2.6.1 worked example" do
    doc = Moxml::Context.new.parse(emitted)
    uos = doc.root
    expect(uos.name).to eq("uos")
    expect(attrs(uos)["id"]).to eq("expdata01")
    expect(attrs(uos)["express"]).to eq("car_ownership")
    # namespace declarations parse back as namespace nodes, not
    # attributes - assert from the serialization
    expect(emitted).to include(
      'xmlns:own="URN:my_company.com:iso_10303_28/car_ownership"',
    )
    # instance elements carry the target-namespace prefix (clause 9
    # worked example)
    expect(emitted).to include("<own:Person")
    # 7.8: the uos element itself is the schema's qualified global
    expect(emitted).to include("<own:uos")

    person = find_elem(uos, "Person")
    expect(attrs(person)["id"]).to eq("id10")
    expect(find_elem(person, "Name").text).to eq("John Q. Public")
    expect(attrs(find_elem(person, "Owns"))["ref"]).to eq("id20")

    car = find_elem(uos, "Car")
    expect(attrs(car)["id"]).to eq("id20")
    expect(find_elem(car, "Car_model").text).to eq("Z3")
  end

  it "emits deterministically" do
    population2 = parse_population(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('p21.pop','2026-10-22T00:00:00',(''),'','','','');
      FILE_SCHEMA(('CAR_OWNERSHIP'));
      ENDSEC;
      DATA;
      #10=PERSON('John Q. Public',#20);
      #20=CAR('BMW','Z3');
      ENDSEC;
      END-ISO-10303-21;
    P21
    expect(described_class.emit(population2, schema, id: "expdata01",
                                                     prefix: "own")).to eq(emitted)
  end

  describe "value encodings" do
    let(:values_schema) do
      parse_express(<<~EXPRESS)
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
    end

    let(:values_population) do
      parse_population(<<~P21)
        ISO-10303-21;
        HEADER;
        FILE_NAME('v.pop','2026-10-22T00:00:00',(''),(''),'','','');
        FILE_SCHEMA(('VALUES_DEMO'));
        ENDSEC;
        DATA;
        #1=BOX('bin',7,2.5,.T.,.UNKNOWN.,.green.,'0AFF',('a','b'),(#2));
        #2=WIDGET(9);
        ENDSEC;
        END-ISO-10303-21;
      P21
    end

    let(:values_emitted) do
      described_class.emit(values_population, values_schema,
                           target_namespace: "URN:t:values_demo",
                           prefix: "vd")
    end

    it "encodes booleans, logicals, enumerations and lists per clause 9" do
      doc = Moxml::Context.new.parse(values_emitted)
      box = find_elem(doc.root, "Box")
      text_of = ->(tag) { find_elem(box, tag)&.text }
      expect(text_of.call("Label")).to eq("bin")
      expect(text_of.call("Count")).to eq("7")
      expect(text_of.call("Ratio")).to eq("2.5")
      expect(text_of.call("Flag")).to eq("true") # 9.5.2
      expect(text_of.call("State")).to eq("unknown") # 9.5.4
      expect(text_of.call("Hue")).to eq("green") # 9.6.1
      expect(text_of.call("Bits")).to eq("0AFF") # 9.5.1 hexBinary
      expect(text_of.call("Tags")).to eq("a b") # 9.8.1 LIST text
    end

    it "names entity-aggregate components after their target instance " \
       "as qualified instance elements" do
      doc = Moxml::Context.new.parse(values_emitted)
      box = find_elem(doc.root, "Box")
      parts = find_elem(box, "Parts")
      item = elems(parts).first
      expect(item.name).to eq("Widget") # named by the target entity
      expect(attrs(item)["ref"]).to eq("id2")
    end

    it "omits the element for a $ slot" do
      omitted = parse_population(<<~P21)
        ISO-10303-21;
        HEADER;
        FILE_NAME('o.pop','2026-10-22T00:00:00',(''),(''),'','','','');
        FILE_SCHEMA(('VALUES_DEMO'));
        ENDSEC;
        DATA;
        #1=BOX($,7,2.5,.T.,.UNKNOWN.,.green.,'0AFF',('a'),(#2));
        #2=WIDGET(9);
        ENDSEC;
        END-ISO-10303-21;
      P21
      doc = Moxml::Context.new.parse(
        described_class.emit(omitted, values_schema,
                             target_namespace: "URN:t:values_demo",
                             prefix: "vd"),
      )
      box = find_elem(doc.root, "Box")
      names = elems(box).map(&:name)
      expect(names).not_to include("Label")
      expect(names).to include("Count")
    end
  end

  it "emits complex entities as exp:complexEntity with one child per role" do
    complex_schema = parse_express(<<~EXPRESS)
      SCHEMA pair_demo;
        ENTITY base_a;
          shared : INTEGER;
        END_ENTITY;
        ENTITY base_b;
          extra : STRING;
        END_ENTITY;
        SUBTYPE_CONSTRAINT ab FOR base_a;
          ABSTRACT SUPERTYPE;
        END_SUBTYPE_CONSTRAINT;
      END_SCHEMA;
    EXPRESS
    complex_population = parse_population(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('c.pop','2026-10-22T00:00:00',(''),(''),'','','','');
      FILE_SCHEMA(('PAIR_DEMO'));
      ENDSEC;
      DATA;
      #1=(BASE_A(3)BASE_B('x'));
      ENDSEC;
      END-ISO-10303-21;
    P21
    complex_emitted = described_class.emit(
      complex_population, complex_schema,
      target_namespace: "URN:t:pair", prefix: "pd"
    )
    doc = Moxml::Context.new.parse(complex_emitted)
    complex_node = elems(doc.root).first
    expect(complex_node.name).to eq("complexEntity")
    expect(complex_emitted).to include("exp:complexEntity")
    expect(attrs(complex_node)["id"]).to eq("id1")
    roles = elems(complex_node).map(&:name)
    expect(roles).to eq(%w[Base_a Base_b])
    expect(complex_emitted).to include("<pd:Base_a>")
  end
end
