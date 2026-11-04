# lib/expressir/changes.rb
module Expressir
  module Changes
    autoload :SchemaChange, "#{__dir__}/changes/schema_change"
    autoload :VersionChange, "#{__dir__}/changes/version_change"
    autoload :ItemChange, "#{__dir__}/changes/item_change"
    autoload :MappingChange, "#{__dir__}/changes/mapping_change"
  end
end
