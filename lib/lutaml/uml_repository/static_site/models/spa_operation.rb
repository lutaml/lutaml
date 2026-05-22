# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaOperation < SpaBase
          attribute :id, :string
          attribute :name, :string
          attribute :visibility, :string
          attribute :return_type, :string
          attribute :owner, :string
          attribute :owner_name, :string
          attribute :parameters, SpaParameter, collection: true,
                                               initialize_empty: true
          attribute :is_static, :boolean, default: false
          attribute :is_abstract, :boolean, default: false

          json do
            map "id", to: :id
            map "name", to: :name
            map "visibility", to: :visibility
            map "returnType", to: :return_type
            map "owner", to: :owner
            map "ownerName", to: :owner_name
            map "parameters", to: :parameters, render_empty: true
            map "isStatic", to: :is_static, render_default: true
            map "isAbstract", to: :is_abstract, render_default: true
          end
        end
      end
    end
  end
end
