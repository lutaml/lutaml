# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.instance/01 parts 2-3: value/type conformance over the
# clause-12 slots (ISO 10303-11 ch.8 domains, 9.2.1 attribute
# domains, 9.2.2.2 domain rules, 9.2.5.2 complex instantiation).
# One firing and one clean example per rule; a mutation sweep asserts
# each corruption produces exactly its intended finding.
RSpec.describe Expressir::P21::Validator do
  let(:schema) do
    Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
      SCHEMA slots_demo;
      TYPE positive = INTEGER;
      WHERE positive_value : SELF > 0;
      END_TYPE;
      TYPE name = STRING; END_TYPE;
      TYPE int_list = LIST [2:?] OF positive; END_TYPE;
      TYPE person = SELECT (worker, manager); END_TYPE;
      ENTITY worker;
        handle : name;
        wage : positive;
      END_ENTITY;
      ENTITY manager;
        handle : name;
        bonus : REAL;
      END_ENTITY;
      ENTITY employee;
        boss : manager;
        team : int_list;
        shade : INTEGER;
      END_ENTITY;
      ENTITY label_box;
        labels : SET [1:2] OF name;
        codes : ARRAY [2:3] OF OPTIONAL positive;
        fixed_codes : ARRAY [2:3] OF positive;
        raw : BINARY;
        who : LOGICAL;
      END_ENTITY;
      END_SCHEMA;
    EXP
  end

  def clean_body
    <<~P21.chomp
      #1=WORKER('ann',50);
      #2=MANAGER('bob',1.5);
      #3=EMPLOYEE(#2,(50,60),7);
      #4=LABEL_BOX(('a','b'),(60,70),(60,70),"0A1F",.U.);
    P21
  end

  def clean_population
    population_for(clean_body)
  end

  def population_for(body)
    Expressir::P21::Parser.parse(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('demo.stp','2026-10-21T00:00:00',('author'),('org'),'pre','source','authorization');
      FILE_SCHEMA(('slots_demo'));
      ENDSEC;
      DATA;
      #{body}
      ENDSEC;
      END-ISO-10303-21;
    P21
  end

  def notes_for(body)
    described_class.validate(population_for(body), schema)
  end

  def messages_for(body)
    notes_for(body).filter_map { |note| note.message if note.severity == :error }
  end

  describe "clause-12 slot value domains (ISO 10303-11 ch.8)" do
    it "accepts the clean population with zero findings" do
      expect(messages_for(clean_body)).to be_empty
    end

    it "flags a real value in an INTEGER slot (8.1.3)" do
      messages = messages_for("#2=MANAGER('bob',1.5);\n#3=EMPLOYEE(#2,(50,60),7.5);")
      expect(messages.join).to include("8.1.3")
    end

    it "accepts an integer in a REAL slot (8.1.2)" do
      expect(messages_for("#2=MANAGER('bob',3);")).to be_empty
    end

    it "accepts an integer in a NUMBER slot (8.1.1)" do
      expect(messages_for("#1=WORKER('ann',50);")).to be_empty
    end

    it "flags a number in a STRING slot (8.1.6)" do
      messages = messages_for("#1=WORKER(9,50);\n#2=MANAGER('bob',1.5);\n#3=EMPLOYEE(#2,(50,60),7);")
      expect(messages.join).to include("8.1.6")
      expect(messages.join).to include("8.1.6")
    end

    it "flags a string in a BINARY slot (8.1.7)" do
      messages = messages_for(
        "#4=LABEL_BOX(('a','b'),(60,70),(60,70),'oops',.U.);",
      )
      expect(messages.join).to include("8.1.7")
    end

    it "accepts UNKNOWN in a LOGICAL slot (8.1.4)" do
      expect(messages_for("#4=LABEL_BOX(('a','b'),(60,70),(60,70),\"0A1F\",.U.);"))
        .to be_empty
    end

    it "flags .Q. in a LOGICAL slot (8.1.4)" do
      messages = messages_for(
        "#4=LABEL_BOX(('a','b'),(60,70),(60,70),\"0A1F\",.Q.);",
      )
      expect(messages.join).to include("8.1.4")
    end
  end

  describe "domain rules on defined types (9.2.2.2)" do
    it "accepts a satisfying value" do
      expect(messages_for("#1=WORKER('ann',50);")).to be_empty
    end

    it "flags a value violating the WHERE of the defined type" do
      messages = messages_for("#1=WORKER('ann',-1);")
      expect(messages.join).to include("positive_value")
      expect(messages.join).to include("9.2.2.2")
    end
  end

  describe "aggregates (8.2.1-8.2.4)" do
    it "flags a LIST below its bound (8.2.2)" do
      messages = messages_for("#2=MANAGER('bob',1.5);\n#3=EMPLOYEE(#2,(50),7);")
      expect(messages.join).to include("8.2.2")
    end

    it "flags duplicate SET elements (8.2.4)" do
      messages = messages_for(
        "#4=LABEL_BOX(('a','a'),(60,70),(60,70),\"0A1F\",.U.);",
      )
      expect(messages.join).to include("8.2.4")
    end

    it "flags an unset element of a non-OPTIONAL ARRAY (8.2.1)" do
      messages = messages_for(
        "#4=LABEL_BOX(('a','b'),(60,70),($,60,70),\"0A1F\",.U.);",
      )
      expect(messages.join).to include("8.2.1")
    end

    it "flags a scalar where an aggregate is declared (8.2)" do
      messages = messages_for("#2=MANAGER('bob',1.5);\n#3=EMPLOYEE(#2,50,7);")
      expect(messages.join).to include("aggregate value")
    end

    it "types elements through the declared element type" do
      messages = messages_for("#2=MANAGER('bob',1.5);\n#3=EMPLOYEE(#2,(50,-8),7);")
      expect(messages.join).to include("element 1")
      expect(messages.join).to include("9.2.2.2")
    end
  end

  describe "attribute domains across references (9.2.1)" do
    it "accepts a reference whose instance conforms to the domain" do
      expect(
        messages_for("#2=MANAGER('bob',1.5);\n#3=EMPLOYEE(#2,(50,60),7);"),
      ).to be_empty
    end

    it "flags a reference to an instance outside the domain (9.2.1)" do
      messages = messages_for("#1=WORKER('ann',50);\n#3=EMPLOYEE(#1,(50,60),7);")
      expect(messages.join).to include("'manager' is required")
      expect(messages.join).to include("9.2.1")
    end
  end

  describe "SELECT membership via instance typing (8.4.2)" do
    let(:select_schema) do
      Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
        SCHEMA select_demo;
        TYPE name = STRING; END_TYPE;
        TYPE whoever = SELECT (worker, manager); END_TYPE;
        ENTITY worker;
          handle : name;
        END_ENTITY;
        ENTITY manager;
          handle : name;
        END_ENTITY;
        ENTITY gadget;
          owner : whoever;
        END_ENTITY;
        ENTITY filler;
          n : INTEGER;
        END_ENTITY;
        END_SCHEMA;
      EXP
    end

    def select_messages(body)
      described_class.validate(population_for(body), select_schema)
        .filter_map { |note| note.message if note.severity == :error }
    end

    it "accepts a reference inside the SELECT domain" do
      expect(select_messages("#1=WORKER('ann');\n#4=GADGET(#1);")).to be_empty
    end

    it "flags a reference outside every arm (8.4.2)" do
      messages = select_messages("#6=FILLER(1);\n#4=GADGET(#6);")
      expect(messages.join).to include("8.4.2")
    end
  end

  describe "complex instantiation through the validator (9.2.5.2)" do
    let(:oneof_schema) do
      Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
        SCHEMA oneof_demo;
        ENTITY product ABSTRACT SUPERTYPE OF (ONEOF(material, document));
        END_ENTITY;
        ENTITY material SUBTYPE OF (product); code : INTEGER; END_ENTITY;
        ENTITY document SUBTYPE OF (product); text : STRING; END_ENTITY;
        END_SCHEMA;
      EXP
    end

    it "flags a ONEOF violation in a complex instance (9.2.5.2)" do
      population = population_for("#9=(MATERIAL(1)DOCUMENT('t'));")
      notes = described_class.validate(population, oneof_schema)
      oneof = notes.find { |note| note.id == :check_p21_complex_instantiation }
      expect(oneof.message).to include("9.2.5.2")
    end
  end

  describe "mutation sweep" do
    it "yields exactly the intended finding per corruption" do
      sweep = [
        ["#3=EMPLOYEE(#2,(50,60),7);", "#3=EMPLOYEE(#1,(50,60),7);",
         :check_p21_reference_type, "9.2.1"],
        ["#3=EMPLOYEE(#2,(50,60),7);", "#3=EMPLOYEE(#2,(50),7);",
         :check_p21_aggregate, "8.2.2"],
        ["#4=LABEL_BOX(('a','b'),(60,70),(60,70),\"0A1F\",.U.);",
         "#4=LABEL_BOX(('a','a'),(60,70),(60,70),\"0A1F\",.U.);",
         :check_p21_aggregate, "8.2.4"],
        ["#1=WORKER('ann',50);", "#1=WORKER('ann',-1);",
         :check_p21_value_domain, "9.2.2.2"],
        ["#4=LABEL_BOX(('a','b'),(60,70),(60,70),\"0A1F\",.U.);",
         "#4=LABEL_BOX(('a','b'),(60,70),(60,70),'oops',.U.);",
         :check_p21_value_domain, "8.1.7"],
      ]
      sweep.each do |original, replacement, expected_id, expected_clause|
        body = clean_body.sub(original, replacement)
        notes = notes_for(body).select { |note| note.severity == :error }
        matching = notes.count { |note| note.id == expected_id }
        expect(matching).to eq(1),
                            "#{replacement}: expected one #{expected_id}, " \
                            "got #{notes.map { |n| [n.id, n.message] }}"
        expect(notes.join).to include(expected_clause)
      end
    end
  end

  describe "Annex H population end to end" do
    let(:annex_h_schema) do
      Expressir::Express::Parser.from_file(
        Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp"),
      ).schemas.first
    end

    it "validates clean with the full conformance stack" do
      population = Expressir::P21::Parser.parse(
        File.read(Expressir.root_path.join("spec/fixtures/p21/annex_h.p21")),
      )
      notes = described_class.validate(
        population, annex_h_schema,
        short_names: { "CPT" => "cartesian_point", "VX" => "vertex",
                       "ED" => "edge",
                       "ED_STRC" => "edge_logical_structure",
                       "ED_LOOP" => "edge_loop" }
      )
      expect(notes).to be_empty
    end
  end
end
