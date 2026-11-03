require "spec_helper"

RSpec.describe Expressir::Express::AstKeyConverter do
  describe ".convert" do
    it "converts CamelCase keys at every depth" do
      input = { "SimpleId" => "x", nested: { "EntityType" => [{ "UpperId" => 1 }] } }

      expect(described_class.convert(input))
        .to eq(simple_id: "x", nested: { entity_type: [{ upper_id: 1 }] })
    end

    it "returns the identical object when nothing needs conversion" do
      input = { simple: [{ already: 1 }] }

      expect(described_class.convert(input)).to equal(input)
    end

    it "is idempotent: converted results convert to themselves" do
      once = described_class.convert("SimpleId" => { "NestedKey" => 1 })

      expect(described_class.convert(once)).to equal(once)
    end

    it "marks unchanged containers so re-visits skip the scan" do
      input = { simple: 1 }
      described_class.convert(input)

      expect(input.instance_variable_defined?(:@_expressir_keys_snaked)).to be(true)
      expect(described_class.convert(input)).to equal(input)
    end

    it "does not raise on frozen hashes" do
      frozen = { "SimpleId" => 1, nested: { "FrozenKey" => 2 }.freeze }.freeze

      expect { described_class.convert(frozen) }.not_to raise_error
    end

    it "keeps the marker invisible to equality and marshaling" do
      marked = { simple: 1 }
      described_class.convert(marked)

      expect(marked).to eq(simple: 1)
      expect(Marshal.load(Marshal.dump(marked))).to eq(simple: 1)
    end
  end

  describe ".snake_case" do
    it "snake_cases CamelCase and passes through snake_case unchanged" do
      expect(described_class.snake_case("SimpleId")).to eq(:simple_id)
      expect(described_class.snake_case(:already_snake)).to eq(:already_snake)
      expect(described_class.snake_case("HTTPServer")).to eq(:http_server)
    end
  end
end
