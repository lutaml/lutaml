# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class MetadataBuilder
          def initialize(repository, config = nil)
            @repository = repository
            @config = config
          end

          def build
            cfg_meta = @config&.metadata

            Models::SpaMetadata.new(
              title: resolve_title(cfg_meta),
              description: cfg_meta&.description,
              generated: Time.now.utc.iso8601,
              generator: "lutaml v#{Lutaml::VERSION}",
              version: cfg_meta&.version || "1.0",
              homepage: cfg_meta&.homepage,
              repository_url: cfg_meta&.repository,
              license: cfg_meta&.license,
              authors: serialize_authors(cfg_meta),
              tags: cfg_meta&.tags || [],
              appearance: serialize_appearance(cfg_meta),
              statistics: build_statistics,
            )
          end

          private

          def resolve_title(cfg_meta)
            cfg_meta&.title ||
              @repository.document.title ||
              @repository.document.name
          end

          def serialize_authors(cfg_meta)
            return nil unless cfg_meta&.authors && !cfg_meta.authors.empty?

            cfg_meta.authors.map do |a|
              a.email ? "#{a.name} <#{a.email}>" : a.name
            end.join(", ")
          end

          def serialize_appearance(cfg_meta)
            return nil unless cfg_meta&.appearance

            appearance = cfg_meta.appearance
            result = {}

            if appearance.logos
              logos = {}
              if appearance.logos.square
                logos["square"] = serialize_logo_config(appearance.logos.square)
              end
              if appearance.logos.long
                logos["long"] = serialize_logo_config(appearance.logos.long)
              end
              result["logos"] = logos unless logos.empty?
            end

            result.to_json
          end

          def serialize_logo_config(logo_config)
            {
              light: { path: logo_config.light&.path,
                       url: logo_config.light&.url }.compact,
              dark: { path: logo_config.dark&.path,
                      url: logo_config.dark&.url }.compact,
            }
          end

          def build_statistics
            Models::SpaStatistics.new(
              packages: @repository.packages_index.size,
              classes: @repository.classes_index.size,
              associations: @repository.associations_index.size,
              attributes: count_total_attributes,
              operations: count_total_operations,
            )
          end

          def count_total_attributes
            @repository.classes_index.sum do |klass|
              klass.attributes&.size || 0
            end
          end

          def count_total_operations
            @repository.classes_index.sum do |klass|
              klass.operations&.size || 0
            end
          end
        end
      end
    end
  end
end
