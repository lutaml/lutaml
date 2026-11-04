# frozen_string_literal: true

require "spec_helper"
require "timeout"

RSpec.describe Lutaml::Model::Utils, ".snake_case on pathological input" do
  {
    "HTTPParser" => "http_parser",
    "XMLSchemaType" => "xml_schema_type",
    "fooBar" => "foo_bar",
    "Foo::BarBaz" => "foo/bar_baz",
    "a1B" => "a1_b",
    "ABc" => "a_bc",
  }.each do |input, expected|
    it "keeps #{input.inspect} => #{expected.inspect}" do
      described_class.instance_variable_set(:@snake_case_cache, nil)
      expect(described_class.snake_case(input)).to eq(expected)
    end
  end

  it "handles a long run of capitals in linear time" do
    described_class.instance_variable_set(:@snake_case_cache, nil)
    expect { Timeout.timeout(1) { described_class.snake_case("A" * 100_000) } }
      .not_to raise_error
  end
end
