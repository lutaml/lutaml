# frozen_string_literal: true

require_relative "id_generator"
require_relative "models/spa_search_entry"

module Lutaml
  module UmlRepository
    module StaticSite
      class SearchIndexBuilder
        attr_reader :repository, :id_generator, :options

        STOP_WORDS = %w[
          the a an and or but in on at to for of with from by
          is are was were be been being have has had
          this that these those it its
        ].freeze

        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IDGenerator.new
        end

        def build
          {
            version: "1.0.0",
            fields: field_definitions,
            ref: "id",
            documentStore: build_document_store,
            pipeline: ["stemmer", "stopWordFilter"],
          }
        end

        private

        def default_options
          {
            languages: ["en"],
          }
        end

        def field_definitions
          [
            { name: "name", boost: 10 },
            { name: "qualifiedName", boost: 5 },
            { name: "type", boost: 3 },
            { name: "package", boost: 2 },
            { name: "content", boost: 1 },
          ]
        end

        def build_document_store
          documents = []

          repository.classes_index.each do |klass|
            documents << build_class_document(klass)

            klass.attributes&.each do |attr|
              documents << build_attribute_document(attr, klass)
            end
          end

          repository.associations_index.each do |assoc|
            documents << build_association_document(assoc)
          end

          repository.packages_index.each do |package|
            documents << build_package_document(package)
          end

          documents
        end

        def build_class_document(klass)
          Models::SpaSearchEntry.new(
            id: @id_generator.document_id("class", klass.xmi_id),
            type: "class",
            entity_type: class_type(klass),
            entity_id: @id_generator.class_id(klass),
            name: klass.name,
            qualified_name: qualified_name(klass),
            package: package_name(klass),
            content: build_class_content(klass),
            boost: 1.5,
          )
        end

        def build_attribute_document(attribute, owner)
          Models::SpaSearchEntry.new(
            id: @id_generator.document_id("attribute",
                                          "#{owner.xmi_id}::#{attribute.name}"),
            type: "attribute",
            entity_type: "Attribute",
            entity_id: @id_generator.attribute_id(attribute, owner),
            name: attribute.name,
            qualified_name: "#{qualified_name(owner)}::#{attribute.name}",
            package: package_name(owner),
            content: build_attribute_content(attribute, owner),
            boost: 1.0,
          )
        end

        def build_association_document(association)
          Models::SpaSearchEntry.new(
            id: @id_generator.document_id("association", association.xmi_id),
            type: "association",
            entity_type: "Association",
            entity_id: @id_generator.association_id(association),
            name: association.name || "unnamed",
            qualified_name: association.name || "unnamed",
            package: "",
            content: build_association_content(association),
            boost: 0.8,
          )
        end

        def build_package_document(package)
          Models::SpaSearchEntry.new(
            id: @id_generator.document_id("package", package.xmi_id),
            type: "package",
            entity_type: "Package",
            entity_id: @id_generator.package_id(package),
            name: package.name,
            qualified_name: package_path(package),
            package: parent_package_name(package),
            content: build_package_content(package),
            boost: 1.2,
          )
        end

        def build_class_content(klass)
          parts = [
            klass.name,
            qualified_name(klass),
            class_type(klass),
            Array(klass.stereotype).join(" "),
            klass.definition,
            klass.attributes&.map(&:name)&.join(" "),
            klass.operations&.map(&:name)&.join(" "),
          ].compact

          normalize_content(parts.join(" "))
        end

        def build_attribute_content(attribute, owner)
          parts = [
            attribute.name,
            attribute.type,
            owner.name,
            qualified_name(owner),
            attribute.definition,
            Array(attribute.stereotype).join(" "),
          ].compact

          normalize_content(parts.join(" "))
        end

        def build_association_content(association)
          parts = [
            association.name,
            association.owner_end,
            association.member_end,
          ].compact

          normalize_content(parts.join(" "))
        end

        def build_package_content(package)
          parts = [
            package.name,
            package_path(package),
            package.definition,
            Array(package.stereotype).join(" "),
          ].compact

          normalize_content(parts.join(" "))
        end

        def normalize_content(text)
          text = text.downcase
          tokens = text.split(/[\s:]+/)
          all_content = [text] + tokens
          all_content = all_content.uniq.reject do |word|
            STOP_WORDS.include?(word)
          end
          all_content.join(" ").gsub(/\s+/, " ").strip
        end

        def class_type(klass)
          klass.class.name.split("::").last
        end

        def qualified_name(klass)
          path_parts = []
          current = klass

          while current
            if current.is_a?(Lutaml::Uml::TopElement) || current.is_a?(Lutaml::Uml::Package)
              path_parts.unshift(current.name)
              current = current.namespace
            else
              break
            end
          end

          path_parts.join("::")
        end

        def package_name(klass)
          return "" unless klass.namespace.is_a?(Lutaml::Uml::Package)

          package_path(klass.namespace)
        end

        def parent_package_name(package)
          return "" unless package.namespace.is_a?(Lutaml::Uml::Package)

          package_path(package.namespace)
        end

        def package_path(package)
          return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

          "#{package_path(package.namespace)}::#{package.name}"
        end
      end
    end
  end
end
