# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Parsers::Yaml do
  describe ".parse" do
    subject(:parse) { described_class.parse(yaml_conent) }

    let(:yaml_conent) do
      fixtures_path("datamodel/views/TopDown.yml")
    end

    it "creates Lutaml::Uml::Document object from yaml" do
      expect(parse).to be_instance_of(Lutaml::Uml::Document)
      expect(parse.name).to eq("TopDown")
      expect(parse.caption).to eq("Address profile model overview in UML")
      expect(parse.title).to eq("Address profile model overview")
      expect(parse.fidelity)
        .to eq({ "hideMembers" => true, "hideOtherClasses" => true })

      # check classes
      expect(parse.classes.count).to eq(10)
      expect(parse.classes.first).to be_instance_of(Lutaml::Uml::Class)
      expect(parse.classes.map(&:name)).to eq(
        [
          "Address",
          "AddressComponent",
          "ProfileCompliantAddress",
          "ProfileCompliantAddressComponent",
          "AddressProfile",
          "AddressClassProfile",
          "InterchangeAddressClassProfile",
          "AddressComponentProfile",
          "AddressComponentSpecification",
          "AttributeProfile",
        ],
      )
      expect(parse.classes.first.associations.first.member_end)
        .to eq("AddressComponent")
      expect(parse.classes.first.associations.first.member_end_attribute_name)
        .to eq("addressComponent")
      expect(parse.classes.first.associations.first.member_end_cardinality.min)
        .to eq("1")
      expect(parse.classes.first.associations.first.member_end_cardinality.max)
        .to eq("*")
      expect(parse.classes.first.associations.first.member_end_type)
        .to eq("direct")
      expect(parse.classes.first.associations.first.owner_end)
        .to eq("Address")
      expect(parse.classes.first.associations.first.owner_end_attribute_name)
        .to eq("address")
      expect(parse.classes.first.associations.first.owner_end_cardinality.min)
        .to eq("1")
      expect(parse.classes.first.associations.first.owner_end_cardinality.max)
        .to eq("*")
      expect(parse.classes.first.associations.first.owner_end_type)
        .to eq("aggregation")
      expect(parse.classes.first.associations.first.visibility)
        .to eq("public")
      expect(parse.classes[4].name).to eq("AddressProfile")
      expect(parse.classes[4].attributes.first.definition)
        .to eq("The country of which this AddressProfile represents.")
      expect(parse.classes[4].attributes.first.name).to eq("country")
      expect(parse.classes[4].attributes.first.type).to eq("iso3166Code")
      expect(parse.classes[4].attributes.first.visibility).to eq("public")

      # check groups
      expect(parse.groups.first).to be_instance_of(Lutaml::Uml::Group)
      expect(parse.groups.first.value.first).to eq("AddressProfile")
      expect(parse.groups.count).to eq(5)
      expect(parse.groups[1].value.count).to eq(3)
      expect(parse.groups[1].value).to eq(
        [
          "InterchangeAddressClassProfile",
          "AddressClassProfile",
          "AddressComponentProfile",
        ],
      )
    end
  end
end
