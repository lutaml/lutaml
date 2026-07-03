# frozen_string_literal: true

require "fileutils"

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
          content = Markdown::IndexPageBuilder.new(repository, options,
                                                   link_resolver).build
          File.write(File.join(output_dir, "index.md"), content)
        end

        def generate_package_pages
          root_path = options[:package] || "ModelRoot"
          packages = repository.list_packages(
            root_path,
            recursive: options.fetch(:recursive, true),
          )

          builder = Markdown::PackagePageBuilder.new(repository, link_resolver)
          packages.each { |pkg| write_package_page(builder, pkg) }
        end

        def write_package_page(builder, package)
          path = link_resolver.package_path(package)
          content = builder.build(package, path)
          filename = link_resolver.sanitize_filename("#{path}.md")
          File.write(File.join(output_dir, "packages", filename), content)
        end

        def generate_class_pages
          classes = collect_export_classes
          builder = Markdown::ClassPageBuilder.new(repository, link_resolver)
          classes.each { |klass| write_class_page(builder, klass) }
        end

        def collect_export_classes
          if options[:package]
            repository.classes_in_package(
              options[:package],
              recursive: options.fetch(:recursive, true),
            )
          else
            indexes&.dig(:classes)&.values || []
          end
        end

        def write_class_page(builder, klass)
          qname = link_resolver.qualified_name(klass)
          content = builder.build(klass, qname)
          filename = link_resolver.sanitize_filename("#{qname}.md")
          File.write(File.join(output_dir, "classes", filename), content)
        end
      end
    end
  end
end
