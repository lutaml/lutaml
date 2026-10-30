# frozen_string_literal: true

require_relative "city_model"
require "lutaml/uml_repository/presenters/class_presenter"

repository = CityModel.repository
element = repository.find_class("ModelRoot::City::Building")
presenter = Lutaml::UmlRepository::Presenters::PresenterFactory.create(element, repository)
puts presenter.to_text
raise "Presenter lost the name" unless presenter.to_hash[:name] == "Building"
