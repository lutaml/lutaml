# frozen_string_literal: true

require_relative "city_model"
require "lutaml/uml/version"

path = ARGV.fetch(0, "browser.html")
Lutaml::UmlRepository::StaticSite.generate(
  CityModel.repository, mode: :single_file, output: path
)
raise "Site was not generated" unless File.size?(path)

puts path
