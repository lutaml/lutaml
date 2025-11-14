# frozen_string_literal: true

require_relative "id_generator"

module Lutaml
  module UmlRepository
    module StaticSite
      # Builds a lunr.js-compatible search index from a UML repository.
      #
      # The index includes:
      # - Document store with searchable content
      # - Field configuration for lunr.js
      # - Pre-processed tokens for efficient client-side search
      #
      # @example
      #   repository = UmlRepository.from_package("model.lur")
      #   builder = SearchIndexBuilder.new(repository)
      #   index = builder.build
      class SearchIndexBuilder
        attr_reader :repository, :id_generator, :options

        STOP_WORDS = %w[
          the a an and or but in on at to for of with from by
          is are was were be been being have has had
          this that these those it its
        ].freeze

        # Initialize search index builder
        #
        # @param repository [UmlRepository] The repository to index
        # @param options [Hash] Builder options
        # @option options [Array<String>] :languages Languages for stemming
        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IDGenerator.new
        end

        # Build the search index
        #
        # @return [Hash] Lunr.js-compatible search index structure
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

        # Define searchable fields with boost values
        def field_definitions
          [
            { name: "name", boost: 10 },
            { name: "qualifiedName", boost: 5 },
            { name: "type", boost: 3 },
            { name: "package", boost: 2 },
            { name: "content", boost: 1 },
          ]
        end

        # Build the document store
        def build_document_store
          # Index classes
          documents = repository.classes_index.map do |klass|
            build_class_document(klass)

            # Index attributes
            next unless klass.attributes

            klass.attributes.each do |attr|
              documents << build_attribute_document(attr, klass)
            end
          end

          # Index associations
          repository.associations_index.each do |assoc|
            documents << build_association_document(assoc)
          end

          # Index packages
          repository.packages_index.each do |package|
            documents << build_package_document(package)
          end

          documents
        end

        # Build search document for a class
        def build_class_document(klass)
          {
            id: @id_generator.document_id("class", klass.xmi_id),
            type: "class",
            entityType: class_type(klass),
            entityId: @id_generator.class_id(klass),
            name: klass.name,
            qualifiedName: qualified_name(klass),
            package: package_name(klass),
            content: build_class_content(klass),
            boost: 1.5, # Classes are more important
          }
        end

        # Build search document for an attribute
        def build_attribute_document(attribute, owner)
          {
            id: @id_generator.document_id("attribute",
                                          "#{owner.xmi_id}::#{attribute.name}"),
            type: "attribute",
            entityType: "Attribute",
            entityId: @id_generator.attribute_id(attribute, owner),
            name: attribute.name,
            qualifiedName: "#{qualified_name(owner)}::#{attribute.name}",
            package: package_name(owner),
            ownerName: owner.name,
            ownerQualifiedName: qualified_name(owner),
            ownerId: @id_generator.class_id(owner),
            content: build_attribute_content(attribute, owner),
            boost: 1.0,
          }
        end

        # Build search document for an association
        def build_association_document(association)
          member_ends = association.member_end || []
          source_class = member_ends[0]&.type
          target_class = member_ends[1]&.type

          {
            id: @id_generator.document_id("association", association.xmi_id),
            type: "association",
            entityType: "Association",
            entityId: @id_generator.association_id(association),
            name: association.name || "unnamed",
            qualifiedName: association.name || "unnamed",
            package: find_association_package(source_class),
            content: build_association_content(association, source_class,
                                               target_class),
            boost: 0.8,
          }
        end

        # Build search document for a package
        def build_package_document(package)
          {
            id: @id_generator.document_id("package", package.xmi_id),
            type: "package",
            entityType: "Package",
            entityId: @id_generator.package_id(package),
            name: package.name,
            qualifiedName: package_path(package),
            package: parent_package_name(package),
            content: build_package_content(package),
            boost: 1.2,
          }
        end

        # Build searchable content for a class
        def build_class_content(klass)
          parts = [
            klass.name,
            qualified_name(klass),
            class_type(klass),
            klass.stereotypes&.join(" "),
            klass.definition,
            klass.attributes&.map(&:name)&.join(" "),
            (klass.respond_to?(:operations) ? klass.operations&.map(&:name)&.join(" ") : nil),
          ].compact

          normalize_content(parts.join(" "))
        end

        # Build searchable content for an attribute
        def build_attribute_content(attribute, owner)
          parts = [
            attribute.name,
            attribute.type,
            owner.name,
            qualified_name(owner),
            attribute.definition,
            attribute.stereotypes&.join(" "),
          ].compact

          normalize_content(parts.join(" "))
        end

        # Build searchable content for an association
        def build_association_content(association, source_class, target_class)
          parts = [
            association.name,
            source_class&.name,
            target_class&.name,
          ].compact

          normalize_content(parts.join(" "))
        end

        # Build searchable content for a package
        def build_package_content(package)
          parts = [
            package.name,
            package_path(package),
            package.definition,
            package.stereotypes&.join(" "),
          ].compact

          normalize_content(parts.join(" "))
        end

        # Normalize content for consistent search
        def normalize_content(text)
          # Remove extra whitespace
          # Convert to lowercase for case-insensitive search
          text.gsub(/\s+/, " ").strip.downcase
        end

        # Helper methods

        def

 class_type(klass)
          klass.class.name.split("::").last
        end

        def qualified_name(klass)
          path_parts = []
          current = klass

          while current
            if current.is_a?(Lutaml::Uml::TopElement)
              path_parts.unshift(current.name)
              current = current.owner
            elsif current.is_a?(Lutaml::Uml::Package)
              path_parts.unshift(current.name)
              current = current.owner
            else
              break
            end
          end

          path_parts.join("::")
        end

        def package_name(klass)
          owner = klass.owner
          return "" unless owner.is_a?(Lutaml::Uml::Package)

          package_path(owner)
        end

        def parent_package_name(package)
          return "" unless package.owner.is_a?(Lutaml::Uml::Package)

          package_path(package.owner)
        end

        def package_path(package)
          return package.name unless package.owner.is_a?(Lutaml::Uml::Package)

          "#{package_path(package.owner)}::#{package.name}"
        end

        def find_association_package(klass)
          return "" unless klass

          package_name(klass)
        end
      end
    end
  end
end
