# frozen_string_literal: true

require "fileutils"
require_relative "base_exporter"
require_relative "../../uml/model_helpers"
require_relative "markdown/link_resolver"
require_relative "markdown/formatting"
require_relative "markdown/index_page_builder"
require_relative "markdown/package_page_builder"
require_relative "markdown/class_page_builder"

module Lutaml
  module UmlRepository
    module Exporters
      class MarkdownExporter < BaseExporter
        include Lutaml::Uml::ModelHelpers
        include Markdown::Formatting

        def export(output_path, options = {})
          @output_dir = output_path
          @options = options

          create_directory_structure
          generate_index_page
          generate_package_pages
          generate_class_pages
        end

        private

        attr_reader :output_dir, :options

        def link_resolver
          @link_resolver ||= Markdown::LinkResolver.new(indexes)
        end

        def create_directory_structure
          FileUtils.mkdir_p(output_dir)
          FileUtils.mkdir_p(File.join(output_dir, "packages"))
          FileUtils.mkdir_p(File.join(output_dir, "classes"))
        end

        def generate_index_page
          content = Markdown::IndexPageBuilder.new(repository, options, link_resolver).build
          File.write(File.join(output_dir, "index.md"), content)
        end

        def generate_package_pages
          root_path = options[:package] || "ModelRoot"
          packages = repository.list_packages(
            root_path,
            recursive: options.fetch(:recursive, true),
          )

          builder = Markdown::PackagePageBuilder.new(repository, link_resolver)
          packages.each do |package|
            path = link_resolver.package_path(package)
            content = builder.build(package, path)
            filename = link_resolver.sanitize_filename("#{path}.md")
            File.write(File.join(output_dir, "packages", filename), content)
          end
        end

        def generate_class_pages
          classes = if options[:package]
                      repository.classes_in_package(
                        options[:package],
                        recursive: options.fetch(:recursive, true),
                      )
                    else
                      indexes&.dig(:classes)&.values || []
                    end

          builder = Markdown::ClassPageBuilder.new(repository, link_resolver)
          classes.each do |klass|
            qname = link_resolver.qualified_name(klass)
            content = builder.build(klass, qname)
            filename = link_resolver.sanitize_filename("#{qname}.md")
            File.write(File.join(output_dir, "classes", filename), content)
          end
        end
      end
    end
  end
end
