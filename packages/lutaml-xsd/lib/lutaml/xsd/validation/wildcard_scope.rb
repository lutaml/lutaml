# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Wildcard namespace-range and content-model containment queries
      # shared by the rule engine's subtree walk and the particle
      # walking rules.
      module WildcardScope
        # Container classes and the child-particle accessors each
        # supports (Class-keyed: the model classes differ in shape).
        PARTICLE_CHILD_ACCESSORS = {
          Lutaml::Xml::Schema::Xsd::Sequence =>
            %i[element any sequence choice group],
          Lutaml::Xsd::Choice => %i[element any sequence choice group],
          Lutaml::Xml::Schema::Xsd::Choice =>
            %i[element any sequence choice group],
          Lutaml::Xsd::All => %i[element],
          Lutaml::Xml::Schema::Xsd::All => %i[element],
        }.freeze

        def expand_group_container(group, repository, depth = 0)
          return [] unless repository
          return [] if depth > 5

          local = (group.ref || group.name).to_s.split(":").last
          declaration = repository.resolve_group(local)
          return [] unless declaration

          container = Array(declaration.sequence).first ||
            Array(declaration.choice).first || Array(declaration.all).first
          container ? [container] : []
        end

        # processContents defaults to strict when absent (XSD 1.0
        # §3.9.2); wildZ001/wildO006 rely on the default.
        #
        # @return [String]
        def wildcard_process_mode(wildcard)
          mode = wildcard.process_contents.to_s
          mode.empty? ? "strict" : mode
        end

        def collect_wildcards(particle, repository, depth = 0)
          return [] if particle.nil? || depth > 8

          case particle
          when Lutaml::Xml::Schema::Xsd::Any
            return [particle]
          when Lutaml::Xml::Schema::Xsd::Group
            return expand_group_container(particle, repository).flat_map do |container|
              collect_wildcards(container, repository, depth + 1)
            end
          end

          accessors = PARTICLE_CHILD_ACCESSORS.find do |klass, _|
            particle.is_a?(klass)
          end&.last
          return [] unless accessors

          accessors.flat_map do |accessor|
            Array(particle.public_send(accessor)).flat_map do |child|
              collect_wildcards(child, repository, depth + 1)
            end
          end
        end

        # Whether a wildcard's namespace constraint admits the child.
        def wildcard_permits?(wildcard, parent, child, repository)
          child_ns = child.namespace_uri.to_s
          case wildcard.namespace.to_s
          when "##any", ""
            true
          when "##other"
            target = content_model_target_namespace(parent, repository)
            !child_ns.empty? && child_ns != target.to_s
          when "##local"
            child_ns.empty?
          when "##targetNamespace"
            child_ns == content_model_target_namespace(parent,
                                                       repository).to_s
          else
            # space-separated namespace list (##targetNamespace ##local allowed)
            wildcard.namespace.to_s.split(/\s+/).any? do |entry|
              case entry
              when "##local" then child_ns.empty?
              when "##targetNamespace"
                child_ns == content_model_target_namespace(parent,
                                                           repository).to_s
              else entry == child_ns
              end
            end
          end
        end

        # @return [String, nil] The target namespace of the declaration the
        #   content model belongs to.
        def content_model_target_namespace(parent, repository)
          return nil unless repository

          declaration = repository.resolve(parent.name, parent.namespace_uri)
          repository.target_namespace_for(declaration) if declaration
        end
      end
    end
  end
end
