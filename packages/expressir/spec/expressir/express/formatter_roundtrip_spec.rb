require "spec_helper"

RSpec.describe Expressir::Express::Formatter do
  def assert_roundtrip(exp_text)
    repo1 = Expressir::Express::Parser.from_exp(exp_text, use_native: false)
    formatted1 = described_class.format(repo1)

    repo2 = Expressir::Express::Parser.from_exp(formatted1, use_native: false)
    formatted2 = described_class.format(repo2)

    strip = ->(t) {
      t.lines.reject do |l|
        l.strip.start_with?("--") || l.strip.empty?
      end.join
    }
    expect(strip.call(formatted1)).to(
      eq(strip.call(formatted2)),
      "Structural content should be stable across format iterations",
    )
  end

  def parse(exp_text)
    Expressir::Express::Parser.from_exp(exp_text, use_native: false)
  end

  describe "unary expression with interval operand" do
    it "wraps interval in parens when negated (NOT {interval})" do
      exp_text = "SCHEMA t; FUNCTION f : BOOLEAN; " \
                 "IF NOT ({1 <= 2 <= 3}) THEN RETURN (TRUE); END_IF; " \
                 "END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end

    it "formats NOT ({interval}) correctly" do
      repo = parse("SCHEMA t; FUNCTION f : BOOLEAN; " \
                   "IF NOT ({1 <= 2 <= 3}) THEN RETURN (TRUE); END_IF; " \
                   "END_FUNCTION; END_SCHEMA;")

      formatted = described_class.format(repo)
      expect(formatted).to include("NOT ({1 <= 2 <= 3})")
      expect(formatted).not_to include("NOT {1 <= 2 <= 3}")
    end
  end

  describe "shorthand variable declarations" do
    it "preserves multiple variables declared on one line" do
      repo = parse("SCHEMA t; FUNCTION f : INTEGER; " \
                   "LOCAL slo, shi : INTEGER; END_LOCAL; " \
                   "RETURN (slo + shi); END_FUNCTION; END_SCHEMA;")

      func = repo.schemas.first.functions.first
      expect(func.variables.length).to eq(2)
      expect(func.variables[0].id).to eq("slo")
      expect(func.variables[1].id).to eq("shi")
      expect(func.variables[0].type).to eq(func.variables[1].type)
    end

    it "roundtrips shorthand variable declarations" do
      exp_text = "SCHEMA t; FUNCTION f : INTEGER; " \
                 "LOCAL slo, shi : INTEGER; END_LOCAL; " \
                 "RETURN (slo + shi); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "procedure VAR parameters" do
    it "preserves VAR parameter flag" do
      repo = parse("SCHEMA t; PROCEDURE p(x : INTEGER; VAR y : INTEGER); " \
                   "END_PROCEDURE; END_SCHEMA;")

      proc = repo.schemas.first.procedures.first
      expect(proc.parameters.length).to eq(2)
      expect(proc.parameters[0].var).to be_nil
      expect(proc.parameters[1].var).to be(true)
    end
  end

  describe "group qualification with index qualifier" do
    it "roundtrips group-qualified index expressions" do
      exp_text = "SCHEMA t; " \
                 "ENTITY sup; field : LIST OF INTEGER; END_ENTITY; " \
                 "ENTITY sub SUBTYPE OF (sup); inc : LIST OF INTEGER; END_ENTITY; " \
                 "FUNCTION f(x : sup) : BOOLEAN; " \
                 "LOCAL v : INTEGER; END_LOCAL; " \
                 "v := x\\sub.field[1]; " \
                 "IF x\\sub.inc[2] >= 0 THEN RETURN (TRUE); END_IF; " \
                 "RETURN (FALSE); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "binary expression parenthesization" do
    it "adds parens for same-precedence left-associative operators" do
      repo = parse("SCHEMA t; FUNCTION f : INTEGER; " \
                   "LOCAL x : INTEGER; END_LOCAL; " \
                   "x := 4 + 2 + 1; RETURN (x); END_FUNCTION; END_SCHEMA;")

      formatted = described_class.format(repo)
      expect(formatted).to include("(4 + 2) + 1")
    end

    it "roundtrips chained binary expressions" do
      exp_text = "SCHEMA t; FUNCTION f : BOOLEAN; " \
                 "LOCAL x : INTEGER; END_LOCAL; " \
                 "x := (4 + 2) - 1; RETURN (x > 0); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "binary literals" do
    it "preserves binary literal formatting" do
      repo = parse("SCHEMA t; FUNCTION f : BOOLEAN; " \
                   "LOCAL x : BINARY; END_LOCAL; " \
                   "x := %01010101; RETURN (TRUE); END_FUNCTION; END_SCHEMA;")

      formatted = described_class.format(repo)
      expect(formatted).to include("%01010101")
    end
  end

  describe "CASE statements" do
    it "roundtrips simple CASE with single label" do
      exp_text = "SCHEMA t; FUNCTION f(x : INTEGER) : BOOLEAN; " \
                 "CASE x OF 1 : RETURN (TRUE); END_CASE; " \
                 "RETURN (FALSE); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end

    it "roundtrips CASE with multiple labels on one action" do
      exp_text = "SCHEMA t; FUNCTION f(x : INTEGER) : BOOLEAN; " \
                 "CASE x OF 1, 2 : RETURN (TRUE); END_CASE; " \
                 "RETURN (FALSE); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end

    it "roundtrips CASE with OTHERWISE" do
      exp_text = "SCHEMA t; FUNCTION f(x : INTEGER) : BOOLEAN; " \
                 "CASE x OF 1 : RETURN (TRUE); OTHERWISE : RETURN (FALSE); END_CASE; " \
                 "RETURN (FALSE); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "formal parameters with multiple IDs" do
    it "preserves multiple parameter IDs sharing a type" do
      repo = parse("SCHEMA t; FUNCTION f(a, b : INTEGER; c : REAL) : INTEGER; " \
                   "RETURN (a + b); END_FUNCTION; END_SCHEMA;")

      func = repo.schemas.first.functions.first
      expect(func.parameters.length).to eq(3)
      expect(func.parameters[0].id).to eq("a")
      expect(func.parameters[1].id).to eq("b")
      expect(func.parameters[2].id).to eq("c")
    end

    it "roundtrips multi-ID parameters" do
      exp_text = "SCHEMA t; FUNCTION f(a, b : INTEGER) : INTEGER; " \
                 "RETURN (a); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "AGGREGATE OF type" do
    it "roundtrips AGGREGATE OF type definition" do
      exp_text = "SCHEMA t; TYPE agg : AGGREGATE OF INTEGER; END_TYPE; END_SCHEMA;"
      skip("AGGREGATE OF not yet supported by parser")
      assert_roundtrip(exp_text)
    end
  end

  describe "SELECT type" do
    it "roundtrips SELECT with multiple items" do
      exp_text = "SCHEMA t; " \
                 "TYPE et1 = BOOLEAN; END_TYPE; " \
                 "TYPE et2 = BOOLEAN; END_TYPE; " \
                 "TYPE s1 = SELECT (et1, et2); END_TYPE; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "interval expressions" do
    it "roundtrips interval in WHERE clause" do
      exp_text = "SCHEMA t; ENTITY e; x : INTEGER; WHERE " \
                 "valid: {0 <= x <= 100}; END_ENTITY; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "nested function declarations" do
    it "roundtrips function with local variables and complex expressions" do
      exp_text = "SCHEMA t; FUNCTION f(x : INTEGER) : INTEGER; " \
                 "LOCAL y : INTEGER; z : REAL; END_LOCAL; " \
                 "y := x * 2; z := y + 1.0; RETURN (y); " \
                 "END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "syntax.exp full roundtrip" do
    it "roundtrips syntax.exp structural content" do
      skip("Parser grammar compatibility — syntax.exp uses features not supported by current parsanol version")
      exp_file = Expressir.root_path.join("spec", "syntax", "syntax.exp")
      repo1 = Expressir::Express::Parser.from_file(exp_file)
      formatted1 = described_class.format(repo1)

      repo2 = Expressir::Express::Parser.from_exp(formatted1, use_native: false)
      formatted2 = described_class.format(repo2)

      strip = ->(t) {
        t.lines.reject do |l|
          l.strip.start_with?("--") || l.strip.empty?
        end.join
      }
      expect(strip.call(formatted1)).to eq(strip.call(formatted2))
    end
  end

  describe "WhereRule remarks" do
    it "attaches tail remarks to WhereRule nodes" do
      repo = parse(<<~EXP)
        SCHEMA t;
          TYPE wt = BOOLEAN;
            WHERE wr1 : TRUE; -- tail remark
          END_TYPE;
        END_SCHEMA;
      EXP

      wr = repo.schemas.first.types.first.where_rules.first
      expect(wr.id).to eq("wr1")
      expect(wr.remarks).to include("tail remark")
    end

    it "roundtrips WHERE clause" do
      exp_text = "SCHEMA t; ENTITY e; x : INTEGER; " \
                 "WHERE valid: x > 0; END_ENTITY; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "END_RULE tail remark" do
    it "preserves tail remark on END_RULE via PrettyFormatter" do
      repo = parse(<<~EXP)
        SCHEMA t;
          ENTITY e;
          END_ENTITY;

          RULE r FOR (e);
          WHERE
            wr1 : TRUE;
          END_RULE;
        END_SCHEMA;
      EXP

      rule = repo.schemas.first.rules.first
      rule.untagged_remarks ||= []
      rule.untagged_remarks << Expressir::Model::RemarkInfo.new(
        text: "end rule remark", format: "tail",
      )

      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      expect(formatted).to include("END_RULE; -- end rule remark")
    end
  end

  describe "constant block" do
    it "roundtrips schema with constants" do
      skip("CONSTANT grammar not supported by current parser version")
      exp_text = "SCHEMA t; CONSTANT pi : REAL := 3.14159; END_CONSTANT; " \
                 "END_SCHEMA;"
      assert_roundtrip(exp_text)
    end

    it "roundtrips function with constants" do
      skip("CONSTANT grammar not supported by current parser version")
      exp_text = "SCHEMA t; FUNCTION f : REAL; " \
                 "CONSTANT pi : REAL := 3.14; END_CONSTANT; " \
                 "RETURN (pi); END_FUNCTION; END_SCHEMA;"
      assert_roundtrip(exp_text)
    end
  end

  describe "binary literal prefix" do
    it "includes % prefix in formatted output" do
      repo = parse("SCHEMA t; FUNCTION f : BOOLEAN; " \
                   "LOCAL x : BINARY; END_LOCAL; " \
                   "x := %01010101; RETURN (TRUE); END_FUNCTION; END_SCHEMA;")

      formatted = described_class.format(repo)
      expect(formatted).to include("%01010101")
      expect(formatted).not_to include(":= 01010101")
    end
  end

  describe "PrettyFormatter scope declarations" do
    it "roundtrips function via PrettyFormatter" do
      repo = parse("SCHEMA t; FUNCTION f(x : INTEGER) : INTEGER; " \
                   "RETURN (x); END_FUNCTION; END_SCHEMA;")
      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      repo2 = Expressir::Express::Parser.from_exp(formatted, use_native: false)
      formatted2 = Expressir::Express::PrettyFormatter.new.format(repo2)

      strip = ->(t) {
        t.lines.reject { |l| l.strip.start_with?("--") || l.strip.empty? }.join
      }
      expect(strip.call(formatted)).to eq(strip.call(formatted2))
    end

    it "roundtrips procedure via PrettyFormatter" do
      repo = parse("SCHEMA t; PROCEDURE p(x : INTEGER); " \
                   "END_PROCEDURE; END_SCHEMA;")
      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      repo2 = Expressir::Express::Parser.from_exp(formatted, use_native: false)
      formatted2 = Expressir::Express::PrettyFormatter.new.format(repo2)

      strip = ->(t) {
        t.lines.reject { |l| l.strip.start_with?("--") || l.strip.empty? }.join
      }
      expect(strip.call(formatted)).to eq(strip.call(formatted2))
    end

    it "roundtrips rule via PrettyFormatter" do
      repo = parse("SCHEMA t; ENTITY e; END_ENTITY; " \
                   "RULE r FOR (e); WHERE wr1 : TRUE; END_RULE; END_SCHEMA;")
      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      repo2 = Expressir::Express::Parser.from_exp(formatted, use_native: false)
      formatted2 = Expressir::Express::PrettyFormatter.new.format(repo2)

      strip = ->(t) {
        t.lines.reject { |l| l.strip.start_with?("--") || l.strip.empty? }.join
      }
      expect(strip.call(formatted)).to eq(strip.call(formatted2))
    end
  end
end
