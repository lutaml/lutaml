# frozen_string_literal: true

require "moxml"

module Expressir
  module P28
    # The binding configuration (TODO.p28/05): ISO 10303-28:2007
    # clause 8 directives over the clause 7 default binding, read from
    # the configuration document (annex D configuration.xsd, namespace
    # urn:iso10303-28:ex).
    #
    # Applied by the derived XML schema:
    # - configuration/@targetNamespace — the 7.7.2 namespace URI is
    #   configuration-chosen instead of default;
    # - option/@naming-convention — the 7.1.2 identifier mapping
    #   (initial-upper is the default; camel-case, preserve-case);
    # - type/@name, entity/@name, attribute/@name — explicit renames,
    #   clause 8.
    #
    # Every other directive in the configuration document (exp-type,
    # exp-attribute, content, flatten, sparse, tagless, keep, use-id,
    # invert, tag-source/tag-values, notation, map, inheritance,
    # occurrence bounds) is parsed and preserved but not applied by
    # this derivation — registered as divergence D-04 in
    # docs/_guides/compat/interchange.adoc.
    class Configuration
      NAMING_CONVENTIONS = %w[initial-upper camel-case preserve-case].freeze
      CONFIG_NS = "urn:iso10303-28:ex"

      Scope = Struct.new(:types, :entities, :attributes, keyword_init: true)

      attr_reader :target_namespace, :scopes
      attr_accessor :naming_convention

      def initialize(naming_convention: "initial-upper",
                     target_namespace: nil, scopes: Scope.new(
                       types: {}, entities: {}, attributes: {},
                     ))
        @naming_convention = naming_convention
        @target_namespace = target_namespace
        @scopes = scopes
      end

      class << self
        # A configuration with no directives: the derivation must be
        # byte-identical to the unconfigured default binding (clause 8:
        # configuration absent ⇒ default binding).
        def empty
          @empty ||= new
        end

        # Parses the clause 8 configuration document.
        def parse(xml)
          doc = Moxml::Context.new.parse(xml)
          root = doc.root
          unless root&.name == "configuration"
            raise Expressir::UsageError,
                  "configuration document root must be ex:configuration"
          end

          config = new(
            target_namespace: root.attribute("targetNamespace")&.value,
          )
          walk(config, root)
          config
        end

        private

        def walk(config, root)
          scopes = config.scopes
          root.children.each do |node|
            next unless node.element?

            case node.name
            when "option"
              convention = node.attribute("naming-convention")&.value
              if convention && !NAMING_CONVENTIONS.include?(convention)
                raise Expressir::UsageError,
                      "unknown naming-convention #{convention}"
              end
              config.naming_convention = convention if convention
            when "type"
              name = node.attribute("name")&.value
              scopes.types[node.attribute("select").value] = name if name
            when "entity"
              rename_entity(config, node)
            when "attribute"
              # attributes are scoped to their nearest entity ancestor
              entity = ancestor_entity(node)
              name = node.attribute("name")&.value
              if entity && name
                select = node.attribute("select").value
                scopes.attributes["#{entity}.#{select}"] = name
              end
            end
            walk(config, node)
          end
        end

        def rename_entity(config, node)
          name = node.attribute("name")&.value
          select = node.attribute("select")&.value
          return unless name && select

          select.split.each do |entity|
            config.scopes.entities[entity] = name
          end
        end

        def ancestor_entity(node)
          parent = node.parent
          while parent
            return parent.attribute("select").value if parent.element? &&
              parent.name == "entity"

            # The walk stops at the document node: moxml 0.6 adapters do
            # not answer #parent on it.
            parent = parent.is_a?(Moxml::Document) ? nil : parent.parent
          end
          nil
        end
      end
    end
  end
end
