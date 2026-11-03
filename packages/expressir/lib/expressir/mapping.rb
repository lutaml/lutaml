# frozen_string_literal: true

module Expressir
  # MIM application-element mapping model (expressir#88,
  # TODO.parity-ee 18): the typed reader for the `mapping.yaml` files
  # each STEP module carries, and validation of the
  # `<<express:SCHEMA.ITEM,ITEM>>` links they contain against a
  # resolved ARM/MIM repository.
  #
  # The model is lutaml-model Serializable — the yaml face is the
  # module corpus format (top-level `ae` + `sc` keys); fields the
  # corpus carries that v1 does not model (alt_map, descriptions)
  # are ignored by the mapping and survive round-trips untouched in
  # the source files.
  module Mapping
    autoload :RefPath, "#{__dir__}/mapping/refpath"
    autoload :InstanceVerification, "#{__dir__}/mapping/instance_verification"

    EXPRESS_LINK = /<<express:([^,>]+)(?:,([^>]+))?>>/

    class ReferencePath < Lutaml::Model::Serializable
      attribute :content, :string

      key_value do
        map "content", to: :content
      end
    end

    class AttributeMapping < Lutaml::Model::Serializable
      attribute :attribute, :string
      attribute :aimelt, :string
      attribute :inherited_from_entity, :string
      attribute :assertion_to, :string
      attribute :refpath, ReferencePath

      key_value do
        map "attribute", to: :attribute
        map "aimelt", to: :aimelt
        map "inherited_from_entity", to: :inherited_from_entity
        map "assertion_to", to: :assertion_to
        map "refpath", to: :refpath
      end
    end

    # An alternative mapping for an application element (corpus
    # `alt_map:` entries): the same ARM concept mapped through a
    # different MIM route, with its own reference path and rules.
    class AltMap < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :description, ReferencePath
      attribute :aimelt, :string
      attribute :refpath, ReferencePath
      attribute :rules, ReferencePath

      key_value do
        map "id", to: :id
        map "description", to: :description
        map "aimelt", to: :aimelt
        map "refpath", to: :refpath
        map "rules", to: :rules
      end
    end

    class ApplicationElement < Lutaml::Model::Serializable
      attribute :entity, :string
      attribute :aimelt, :string
      attribute :extensible, :string
      attribute :original_module, :string
      attribute :refpath, ReferencePath
      attribute :rules, ReferencePath
      attribute :alt_map, AltMap, collection: true
      attribute :aa, AttributeMapping, collection: true

      key_value do
        map "entity", to: :entity
        map "aimelt", to: :aimelt
        map "extensible", to: :extensible
        map "original_module", to: :original_module
        map "refpath", to: :refpath
        map "rules", to: :rules
        map "alt_map", to: :alt_map
        map "aa", to: :aa
      end
    end

    class SubtypeConstraintMapping < Lutaml::Model::Serializable
      attribute :constraint, :string
      attribute :entity, :string

      key_value do
        map "constraint", to: :constraint
        map "entity", to: :entity
      end
    end

    class Document < Lutaml::Model::Serializable
      attribute :ae, ApplicationElement, collection: true
      attribute :sc, SubtypeConstraintMapping, collection: true

      key_value do
        map "ae", to: :ae
        map "sc", to: :sc
      end
    end

    UnknownLink = Struct.new(:text, :schema, :item, keyword_init: true)

    module_function

    # @param path [String] path to a module mapping.yaml
    # @return [Document]
    def load_file(path)
      Document.from_yaml(File.read(path))
    end

    # Every `<<express:...>>` link in the document, as
    # [schema_id, item_id] pairs (duplicates preserved).
    def links(document)
      values(document).flat_map do |value|
        value.to_s.scan(EXPRESS_LINK).map do |path, _id|
          parts = path.split(".")
          [parts[-2], parts[-1]]
        end
      end
    end

    # Links whose schema or item cannot be found in +repository+.
    # A link with no item part resolves against schema presence only.
    def unknown_links(document, repository)
      known = repository.schemas.to_h do |schema|
        [schema.id.safe_downcase, schema]
      end
      links(document).filter_map do |schema_id, item_id|
        schema = known[schema_id&.safe_downcase]
        if schema.nil?
          next UnknownLink.new(text: "#{schema_id}.#{item_id}",
                               schema: schema_id, item: item_id)
        end
        next if item_id.nil?

        unless item_declared?(schema, item_id)
          next UnknownLink.new(text: "#{schema_id}.#{item_id}",
                               schema: schema_id, item: item_id)
        end

        nil
      end
    end

    def item_declared?(schema, item_id)
      key = item_id.safe_downcase
      %i[types entities functions procedures rules constants
         subtype_constraints].any? do |coll|
        Array(schema.public_send(coll)).any? do |decl|
          decl.respond_to?(:id) && decl.id&.safe_downcase == key
        end
      end
    end

    def values(document)
      document.ae.to_a.flat_map do |element|
        [element.entity, element.aimelt] +
          element.aa.to_a.flat_map do |aa|
            [aa.attribute, aa.aimelt, aa.assertion_to]
          end +
          element.alt_map.to_a.flat_map do |alt|
            [alt.aimelt, alt.description&.content]
          end
      end.compact + subtype_constraint_values(document)
    end

    # Every declaration reference in the sc entries (#460): the
    # constraint name and the entity it constrains.
    def subtype_constraint_values(document)
      document.sc.to_a.flat_map { |sc| [sc.constraint, sc.entity] }.compact
    end

    # Every reference path in the document as [location, content]
    # pairs; location names the application element (and attribute,
    # for attribute-level paths) the path belongs to.
    def refpaths(document)
      document.ae.to_a.flat_map do |element|
        entries = []
        if element.refpath&.content
          entries << [element.entity.to_s, element.refpath.content]
        end
        element.aa.to_a.each do |aa|
          next unless aa.refpath&.content

          entries << ["#{element.entity}.#{aa.attribute}", aa.refpath.content]
        end
        element.alt_map.to_a.each do |alt|
          next unless alt.refpath&.content

          label = alt.id ? "#{element.entity}[#{alt.id}]" : element.entity.to_s
          entries << [label, alt.refpath.content]
        end
        entries
      end
    end

    # Every `rules:` value in the document as [mapped entity, rule
    # name, location label] triples — the rules-list reference
    # position. The mapped entity is the ae entity's declared name
    # (the item of its annotated link).
    def rules_positions(document)
      document.ae.to_a.flat_map do |element|
        entity = entity_item(element.entity)
        positions = []
        if element.rules&.content
          positions << [entity, element.rules.content, element.entity.to_s]
        end
        element.alt_map.to_a.each do |alt|
          next unless alt.rules&.content

          positions << [entity, alt.rules.content,
                        "#{element.entity}[#{alt.id}]"]
        end
        positions
      end
    end

    # The declared item of an annotated link value
    # (<<express:SCHEMA.ITEM,ITEM>> → ITEM; bare value → itself).
    def entity_item(value)
      match = value.to_s.match(EXPRESS_LINK)
      match ? match[2] || match[1].split(".").last : value.to_s
    end

    # ELF 5006 §8 rules-list validation: each named rule must be a
    # global RULE in the repository whose FOR list includes the mapped
    # entity (rule declarations are schema-level).
    def rule_issues(document, repository)
      rules_by_name = repository.schemas.flat_map(&:rules)
        .select { |r| r.respond_to?(:id) && r.id }
        .to_h { |r| [r.id.safe_downcase, r] }
      rules_positions(document).filter_map do |entity, rule, _label|
        decl = rules_by_name[rule.safe_downcase]
        next if decl.nil? == false && entity.nil?
        next if decl && for_list_includes?(decl, entity)

        UnknownLink.new(text: "#{entity}.#{rule}", schema: entity,
                        item: rule)
      end
    end

    def for_list_includes?(rule_decl, entity)
      Array(rule_decl.applies_to).any? do |ref|
        id = ref.respond_to?(:id) ? ref.id : ref.to_s
        id&.safe_downcase == entity.safe_downcase
      end
    end
  end
end
