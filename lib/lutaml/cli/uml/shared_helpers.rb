# frozen_string_literal: true

require_relative "../output_formatter"

module Lutaml
  module Cli
    module Uml
      # SharedHelpers provides common utility methods for UML commands
      #
      # This module is included in command classes to provide shared functionality
      # like repository loading and path normalization, following the DRY principle.
      module SharedHelpers
        # Load repository from LUR file
        #
        # @param lur_path [String] Path to LUR package file
        # @param lazy [Boolean] Whether to use lazy loading
        # @return [Lutaml::UmlRepository::Repository] Loaded repository
        def load_repository(lur_path, lazy: false)
          OutputFormatter.progress("Loading repository from #{lur_path}")
          repo = if lazy
                   Lutaml::UmlRepository::Repository.from_package_lazy(lur_path)
                 else
                   Lutaml::UmlRepository::Repository.from_package(lur_path)
                 end
          OutputFormatter.progress_done
          repo
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Failed to load repository: #{e.message}")
          exit 1
        end

        # Normalize path syntax
        #
        # Converts :: or <RepositoryRoot>:: to ModelRoot
        #
        # @param path [String, nil] Path to normalize
        # @return [String] Normalized path
        def normalize_path(path)
          return "ModelRoot" if path.nil? || path.empty?
          return "ModelRoot" if ["::", "<RepositoryRoot>"].include?(path)

          path = path.sub(/^::/, "ModelRoot::")
          path.sub(/^<RepositoryRoot>::/, "ModelRoot::")
        end
      end
    end
  end
end
