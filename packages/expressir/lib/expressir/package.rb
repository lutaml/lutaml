# lib/expressir/package.rb
module Expressir
  module Package
    autoload :Metadata, "#{__dir__}/package/metadata"
    autoload :Builder, "#{__dir__}/package/builder"
    autoload :Reader, "#{__dir__}/package/reader"
  end
end
