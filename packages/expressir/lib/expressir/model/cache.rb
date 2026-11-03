module Expressir
  module Model
    # Cache content object with Expressir version
    class Cache < ModelElement
      attribute :version, :string
      attribute :root_path, :string
      attribute :content, ModelElement
      attribute :_class, :string, default: -> { self.class.name }

      key_value do
        map "_class", to: :_class, render_default: true
        map "version", to: :version
        map "root_path", to: :root_path
        map "content", to: :content
      end
    end
  end
end
