# frozen_string_literal: true

module Lutaml
  module Uml
    class Model < Package
      attribute :viewpoint, :string

      yaml do
        map "viewpoint", to: :viewpoint
      end
    end
  end
end
