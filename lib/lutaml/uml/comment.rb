# frozen_string_literal: true

module Lutaml
  module Uml
    class Comment < Lutaml::Model::Serializable
      skip_reference_registration

      attribute :text, :string

      yaml do
        map "text", to: :text
      end
    end
  end
end
