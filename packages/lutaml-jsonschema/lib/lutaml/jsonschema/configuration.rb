# frozen_string_literal: true

module Lutaml
  module Jsonschema
    class Configuration < Base
      attribute :title, :string
      attribute :version, :string
      attribute :description, :string
      attribute :base_url, :string
      attribute :theme, :string, default: -> { "light" }
      attribute :output_path, :string, default: -> { "output" }
      attribute :sort_properties, :string
      attribute :appearance, :hash

      key_value do
        map "title", to: :title
        map "version", to: :version
        map "description", to: :description
        map "base_url", to: :base_url
        map "theme", to: :theme
        map "output_path", to: :output_path
        map "sort_properties", to: :sort_properties
        map "appearance", to: :appearance
      end

      def self.load_from_file(path)
        return new unless File.exist?(path)

        from_yaml(File.read(path, encoding: "utf-8"))
      end

      def to_metadata
        Spa::Metadata.new(
          title: title,
          version: version,
          description: description,
          base_url: base_url,
          theme: theme,
          sort_properties: sort_properties,
          appearance: appearance,
        )
      end

      def apply_appearance_overrides(logo:, subtitle:)
        self.appearance ||= {}
        appearance["logos"] ||= {}
        appearance["logos"]["square"] ||= {}
        if logo
          appearance["logos"]["square"]["light"] = { "url" => logo }
          appearance["logos"]["square"]["dark"] = { "url" => logo }
        end
        appearance["subtitle"] = subtitle if subtitle
      end
    end
  end
end
