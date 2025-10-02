# frozen_string_literal: true

module Lutaml
  module Uml
    class Diagram < TopElement
      attribute :package_id, :string
      attribute :package_name, :string

      yaml do
        map "package_id", to: :package_id
        map "package_name", to: :package_name
      end
    end
  end
end
