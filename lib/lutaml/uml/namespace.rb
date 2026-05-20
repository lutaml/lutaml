# frozen_string_literal: true

module Lutaml
  module Uml
    class Namespace < Lutaml::Model::Serializable
      skip_reference_registration

      attribute :name, :string
      attribute :namespace, Namespace
    end
  end
end
