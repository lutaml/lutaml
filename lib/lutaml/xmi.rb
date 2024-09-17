require "lutaml/xmi/version"
require "lutaml/xmi/parsers/xml"
require "liquid"

Dir["#{File.dirname(__FILE__)}/xmi/liquid_drops/**/*.rb"].sort.each do |f|
  require f
end

module Lutaml
  module XMI
  end
end
