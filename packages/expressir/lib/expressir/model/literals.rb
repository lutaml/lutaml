# frozen_string_literal: true

module Expressir
  module Model
    module Literals
      autoload :Binary, "#{__dir__}/literals/binary"
      autoload :Integer, "#{__dir__}/literals/integer"
      autoload :Logical, "#{__dir__}/literals/logical"
      autoload :Real, "#{__dir__}/literals/real"
      autoload :String, "#{__dir__}/literals/string"
    end
  end
end
