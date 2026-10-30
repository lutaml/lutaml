# frozen_string_literal: true

require "lutaml"

module CityModel
  def self.repository
    building = Lutaml::Uml::UmlClass.new(
      name: "Building", xmi_id: "building-1", stereotype: ["featureType"]
    )
    city = Lutaml::Uml::Package.new(
      name: "City", xmi_id: "city-1", classes: [building]
    )
    document = Lutaml::Uml::Document.new(name: "City model", packages: [city])
    Lutaml::UmlRepository::Repository.from_document(document)
  end
end

if $PROGRAM_NAME == __FILE__
  repository = CityModel.repository
  puts repository.find_class("ModelRoot::City::Building").name
end
