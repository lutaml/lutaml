# frozen_string_literal: true

module Expressir
  module Model
    module DataTypes
      autoload :Aggregate, "#{__dir__}/data_types/aggregate"
      autoload :Array, "#{__dir__}/data_types/array"
      autoload :Bag, "#{__dir__}/data_types/bag"
      autoload :Binary, "#{__dir__}/data_types/binary"
      autoload :Boolean, "#{__dir__}/data_types/boolean"
      autoload :Enumeration, "#{__dir__}/data_types/enumeration"
      autoload :EnumerationItem, "#{__dir__}/data_types/enumeration_item"
      autoload :GenericEntity, "#{__dir__}/data_types/generic_entity"
      autoload :Generic, "#{__dir__}/data_types/generic"
      autoload :Integer, "#{__dir__}/data_types/integer"
      autoload :List, "#{__dir__}/data_types/list"
      autoload :Logical, "#{__dir__}/data_types/logical"
      autoload :Number, "#{__dir__}/data_types/number"
      autoload :Real, "#{__dir__}/data_types/real"
      autoload :Select, "#{__dir__}/data_types/select"
      autoload :Set, "#{__dir__}/data_types/set"
      autoload :String, "#{__dir__}/data_types/string"
    end
  end
end
