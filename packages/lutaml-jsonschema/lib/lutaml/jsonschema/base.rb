# frozen_string_literal: true

module Lutaml
  module Jsonschema
    class Base < Lutaml::Model::Serializable
    end

    # Forward declaration for circular references (Schema ↔ PropertyEntry ↔ Link).
    class Schema < Base; end
  end
end
