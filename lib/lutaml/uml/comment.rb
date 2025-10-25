# frozen_string_literal: true

module Lutaml
  module Uml
    class Comment < Lutaml::Model::Serializable
      attribute :text, :string

      yaml do
        map "text", to: :text
      end
    end
  end
end