# frozen_string_literal: true

module Lutaml
  module Uml
    class Fidelity < Lutaml::Model::Serializable
      skip_reference_registration

      attribute :hideMembers, :boolean
      attribute :hideOtherClasses, :boolean
    end
  end
end
