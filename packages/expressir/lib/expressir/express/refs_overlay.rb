# frozen_string_literal: true

module Expressir
  module Express
    # Resolved references are deterministic given the sources and the
    # repository composition, so the batch path persists every
    # SimpleReference's final base_path as an overlay next to the
    # compiled-set artifact; warm loads re-apply them instead of
    # re-running the {ResolveReferencesModelVisitor}.
    module RefsOverlay
      module_function

      def write(set_path, models)
        refs = {}
        ModelTraversal.each_model(models) do |node, key|
          next unless node.is_a?(Model::References::SimpleReference)
          next if node.base_path.nil?

          refs[key] = node.base_path
        end
        return if refs.empty?

        require "json"
        File.write("#{set_path}.refs.json", JSON.generate(refs))
      end

      # Re-binds resolved references from the compiled-set refs
      # sidecar. Returns the sidecar path when it was applied (caller
      # then skips the resolver); nil when absent — caller falls back
      # to resolving.
      def apply_to(set_path, models)
        refs_path = "#{set_path}.refs.json"
        return nil unless File.exist?(refs_path)

        require "json"
        refs = JSON.parse(File.read(refs_path))
        ModelTraversal.each_model(models) do |node, key|
          next unless node.is_a?(Model::References::SimpleReference)

          base_path = refs[key]
          node.base_path = base_path unless base_path.nil?
        end
        refs_path
      end
    end
  end
end
