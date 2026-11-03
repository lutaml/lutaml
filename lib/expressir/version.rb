module Expressir
  # Gem version. Wrapped in a Version module so that lib/expressir.rb can
  # autoload it (Ruby autoload only works for module/class constants, not
  # for string constants like `Expressir::VERSION`).
  module Version
    VERSION = "2.4.52".freeze
  end
end
