# frozen_string_literal: true

require_relative "city_model"
# lutaml-uml 1.0.3's exporter uses this component's version constant.
require "lutaml/uml/version"

path = ARGV.fetch(0, "city.lur")
CityModel.repository.export_to_package(path)
repository = Lutaml::UmlRepository::Repository.from_package(path)
raise "Class was not preserved" unless repository.find_class("ModelRoot::City::Building")

puts repository.find_class("ModelRoot::City::Building").name
