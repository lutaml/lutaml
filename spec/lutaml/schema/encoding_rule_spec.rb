# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/schema/encoding_rule"

RSpec.describe Lutaml::Schema::EncodingRule do
  def attribute(name, tags = {})
    Lutaml::Uml::TopElementAttribute.new(
      name: name,
      tagged_values: tags.map do |key, value|
        Lutaml::Uml::TaggedValue.new(name: key.to_s, value: value.to_s)
      end,
    )
  end

  let(:attributes) do
    [
      attribute("id", xmlAttribute: "true"),
      attribute("street", sequenceNumber: 2),
      attribute("city", sequenceNumber: 1),
      attribute("note"),
    ]
  end

  let(:classified) { described_class.new.classify(attributes) }

  it "treats xmlAttribute-tagged attributes as XML attributes" do
    expect(classified[:attributes].map(&:name)).to eq(["id"])
  end

  it "orders elements by sequenceNumber, then declaration order",
     :aggregate_failures do
    expect(classified[:elements].map(&:name)).to eq(%w[city street note])
  end

  it "treats only true/yes/1 as an XML attribute", :aggregate_failures do
    expect(described_class.new.xml_attribute?(attribute("a", xmlAttribute: "true")))
      .to be(true)
    expect(described_class.new.xml_attribute?(attribute("b", xmlAttribute: "false")))
      .to be(false)
    expect(described_class.new.xml_attribute?(attribute("c"))).to be(false)
  end

  it "returns empty groups for nil attributes" do
    expect(described_class.new.classify(nil))
      .to eq(elements: [], attributes: [])
  end
end
