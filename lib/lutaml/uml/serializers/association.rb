# frozen_string_literal: true

require "lutaml/uml/serializers/base"
require "lutaml/uml/serializers/class"

module Lutaml
  module Uml
    module Serializers
      class Association < Base
        property :member_end, from: :target
        property :member_end_attribute_name,
                 from: "relationship",
                 transform_with: (lambda do |val|
                   val.dig("target", "attributes")&.keys&.first ||
                    val.dig("target", "attribute")&.keys&.first
                 end)
        property :member_end_cardinality,
                 from: "relationship",
                 transform_with: (lambda do |val|
                   res = val.dig("source", "attributes")&.values&.first ||
                          val.dig("source", "attribute")&.values&.first
                   res["cardinality"] if res
                 end)
        property :member_end_type,
                 from: "relationship",
                 transform_with: (lambda do |val|
                   val.dig("target", "type")
                 end)
        property :owner_end_attribute_name,
                 from: "relationship",
                 transform_with: (lambda do |val|
                   val.dig("source", "attributes")&.keys&.first ||
                     val.dig("source", "attribute")&.keys&.first
                 end)
        property :owner_end_cardinality,
                 from: "relationship",
                 transform_with: (lambda do |val|
                   res = val.dig("source", "attributes")&.values&.first ||
                           val.dig("source", "attribute")&.values&.first
                   res["cardinality"] if res
                 end)
        property :owner_end_type,
                 from: "relationship",
                 transform_with: (lambda do |val|
                   val.dig("source", "type")
                 end)
        property :action,
                 transform_with: (lambda do |val|
                   if val["direction"] == "target"
                     "#{val['verb']} ▶"
                   else
                     "◀ #{val['verb']}"
                   end
                 end)
      end
    end
  end
end
