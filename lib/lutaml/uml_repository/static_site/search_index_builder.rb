# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      class SearchIndexBuilder
        include Lutaml::Uml::ModelHelpers

        STOP_WORDS = %w[
          the a an and or but in on at to for of with from by
          is are was were be been being have has had
          this that these those it its
        ].freeze

        attr_reader :repository, :id_generator, :options

        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IdGenerator.new
        end

        def build
          Models::SpaSearchIndex.new(
            fields: field_definitions,
            document_store: build_document_store,
          )
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
          documents.concat(build_class_documents)
          documents.concat(build_association_documents)
          documents.concat(build_package_documents)
          documents
        end

        def build_class_document(klass)
          Models::SpaSearchEntry.new(
            id: @id_generator.document_id("class", klass.xmi_id),
            type: "class",
            entity_type: class_type(klass),
            entity_id: @id_generator.class_id(klass),
            name: klass.name,
            qualified_name: qualified_name_for(klass),
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
            qualified_name: "#{qualified_name_for(owner)}::#{attribute.name}",
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
            qualified_name: package_path_for(package),
            package: parent_package_name(package),
            content: build_package_content(package),
            boost: 1.2,
          )
        end

        def build_class_content(klass)
          parts = [
            klass.name,
            qualified_name_for(klass),
            class_type(klass),
            Array(klass.stereotype).join(" "),
            klass.definition,
            collect_names(klass.attributes),
            collect_names(klass.operations),
          ].compact

          normalize_content(parts.join(" "))
        end

        def build_attribute_content(attribute, owner)
          parts = [
            attribute.name,
            attribute.type,
            owner.name,
            qualified_name_for(owner),
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
            package_path_for(package),
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

        def build_class_documents
          docs = []
          repository.classes_index.each do |klass|
            docs << build_class_document(klass)
            klass.attributes&.each do |attr|
              docs << build_attribute_document(attr, klass)
            end
          end
          docs
        end

        def build_association_documents
          repository.associations_index.map do |assoc|
            build_association_document(assoc)
          end
        end

        def build_package_documents
          repository.packages_index.map do |package|
            build_package_document(package)
          end
        end

        def collect_names(items)
          items&.map(&:name)&.join(" ")
        end

        def class_type(klass)
          klass.class.name.split("::").last
        end

        def package_name(klass)
          return "" unless klass.namespace.is_a?(Lutaml::Uml::Package)

          package_path_for(klass.namespace)
        end

        def parent_package_name(package)
          return "" unless package.namespace.is_a?(Lutaml::Uml::Package)

          package_path_for(package.namespace)
        end
      end
    end
  end
end
