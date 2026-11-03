# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/value_space"

RSpec.describe Lutaml::Xsd::Validation::ValueSpace do
  describe ".lexical_answer" do
    {
      "xsd:token" => ["a  b", "", "a b"],
      "xsd:integer" => ["0", "-5", "+7", "12345678901234567890123456789"],
      "xsd:long" => ["9223372036854775807", "-9223372036854775808"],
      "xsd:unsignedByte" => %w[0 255],
      "xsd:positiveInteger" => ["1"],
      "xsd:date" => ["2000-02-29", "2024-01-15", "2024-01-15Z",
                     "2024-01-15+05:00"],
      "xsd:dateTime" => ["2024-01-15T10:30:00", "2024-02-29T24:00:00Z"],
      "xsd:time" => ["00:00:00", "23:59:59.5", "24:00:00"],
      "xsd:duration" => ["P1Y", "P1Y2M", "PT1H", "P1Y2MT2H"],
      "xsd:base64Binary" => ["", "YWJj", "YWJjZA=="],
      "xsd:gYear" => ["2024", "-0044"],
      "xsd:gYearMonth" => ["2024-05"],
      "xsd:gMonth" => ["--03", "--03--"],
      "xsd:gMonthDay" => ["--02-29"],
      "xsd:gDay" => ["---15"],
    }.each do |type, values|
      values.each do |value|
        it "accepts #{value.inspect} as #{type}" do
          expect(described_class.lexical_answer(type, value)).to be(true)
        end
      end
    end

    {
      "xsd:date" => ["1999-02-29", "not-a-date", "2024-13-01"],
      "xsd:dateTime" => ["2024-01-15", "2024-02-30T10:00:00"],
      "xsd:time" => ["25:20:00", "13:60:00", "13:20:60", "13:20.4:00"],
      "xsd:duration" => ["P1Y2MT", "P200.5Y", "P", "PT"],
      "xsd:base64Binary" => ["abcde", "YWJjZA==="],
      "xsd:QName" => ["xmlns:xsi", "xs:"],
      "xsd:long" => ["9223372036854775808"],
      "xsd:int" => ["2147483648"],
      "xsd:nonPositiveInteger" => ["1"],
      "xsd:gMonth" => ["--13"],
      "xsd:gDay" => ["---32"],
      "xsd:gMonthDay" => ["--04-31"],
    }.each do |type, values|
      values.each do |value|
        it "rejects #{value.inspect} as #{type}" do
          expect(described_class.lexical_answer(type, value)).to be(false)
        end
      end
    end

    it "defers unprefixed type references to the engine" do
      expect(described_class.lexical_answer("date", "1999-02-29")).to be_nil
    end

    it "defers non-XSD namespaces to the engine" do
      expect(described_class.lexical_answer("tns:date", "1999-02-29"))
        .to be_nil
    end

    it "defers types outside the value-space tables" do
      expect(described_class.lexical_answer("xs:boolean", "maybe")).to be_nil
    end
  end

  describe ".calendar_key" do
    {
      "---15" => [15],
      "--03" => [3],
      "--03--" => [3],
      "--02-29" => [2, 29],
      "2024" => [2024],
      "-0044" => [-44],
      "2024-05" => [2024, 5],
      "2024-01-15" => nil,
      "not-a-date" => nil,
    }.each do |text, expected|
      it "maps #{text.inspect} to #{expected.inspect}" do
        expect(described_class.calendar_key(text)).to eq(expected)
      end
    end
  end

  describe ".measured_length" do
    let(:restriction_class) { Struct.new(:base) }

    it "counts list items for list types" do
      restriction = restriction_class.new("xs:IDREFS")

      expect(described_class.measured_length("a b c", restriction)).to eq(3)
    end

    it "collapses whitespace when counting list items" do
      restriction = restriction_class.new("xs:NMTOKENS")

      expect(described_class.measured_length("  a  b ", restriction)).to eq(2)
    end

    it "counts octets for hexBinary" do
      restriction = restriction_class.new("xs:hexBinary")

      expect(described_class.measured_length("0A1B", restriction)).to eq(2)
    end

    it "counts decoded octets for base64Binary" do
      restriction = restriction_class.new("xs:base64Binary")

      expect(described_class.measured_length("YWJjZA==", restriction)).to eq(4)
    end

    it "counts characters for string types" do
      restriction = restriction_class.new("xs:string")

      expect(described_class.measured_length("abcd", restriction)).to eq(4)
    end
  end
end
