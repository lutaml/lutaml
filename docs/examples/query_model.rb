# frozen_string_literal: true

require_relative "city_model"

repository = CityModel.repository
classes = repository.query do |query|
  query.classes.where(name: "Building")
end.all
raise "Unexpected query result" unless classes.map(&:name) == ["Building"]

puts classes.map(&:name)
puts repository.search("Building", types: [:class])[:total]
