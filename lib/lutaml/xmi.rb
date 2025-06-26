require "lutaml/xmi/parsers/xml"
require "liquid"
require "lutaml/path"

Dir["#{File.dirname(__FILE__)}/xmi/liquid_drops/**/*.rb"].sort.each do |f|
  require f
end

module Lutaml
  module XMI
  end
end
