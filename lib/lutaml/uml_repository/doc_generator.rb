# frozen_string_literal: true

require "fileutils"
require "json"

module Lutaml
  module UmlRepository
    # Static HTML documentation site generator.
    #
    # Generates a complete static HTML documentation site with:
    # - Index page with statistics and package tree
    # - Package hierarchy navigation
    # - Class pages with full details
    # - Client-side search functionality
    # - Responsive design
    #
    # @example Generate documentation
    #   generator = DocGenerator.new(repository)
    #   generator.generate("docs/")
    #
    # @example Generate with custom options
    #   generator.generate("docs/",
    #     title: "My UML Model",
    #     theme: "dark"
    #   )
    class DocGenerator
      # @return [UmlRepository] The repository to document
      attr_reader :repository

      # Initialize a new documentation generator.
      #
      # @param repository [UmlRepository] The repository to document
      def initialize(repository)
        @repository = repository
      end

      # Generate the documentation site.
      #
      # @param output_dir [String] Path to the output directory
      # @param options [Hash] Generation options
      # @option options [String] :title ("UML Model Documentation") Site title
      # @option options [String] :theme ("light") Color theme (light/dark)
      # @option options [String] :package Filter by package path
      # @option options [Boolean] :recursive (true) Include nested packages
      # @return [void]
      def generate(output_dir, options = {})
        @output_dir = output_dir
        @options = options

        create_directory_structure
        generate_index_page
        generate_package_pages
        generate_class_pages
        generate_search_index
        copy_assets
      end

      private

      attr_reader :output_dir, :options

      # Create the directory structure for the documentation site.
      #
      # @return [void]
      def create_directory_structure
        FileUtils.mkdir_p(output_dir)
        FileUtils.mkdir_p(File.join(output_dir, "packages"))
        FileUtils.mkdir_p(File.join(output_dir, "classes"))
        FileUtils.mkdir_p(File.join(output_dir, "assets"))
      end

      # Generate the index page.
      #
      # @return [void]
      def generate_index_page
        content = build_index_html
        File.write(File.join(output_dir, "index.html"), content)
      end

      # Build index page HTML.
      #
      # @return [String] The index page HTML
      def build_index_html
        title = options.fetch(:title, "UML Model Documentation")
        stats = repository.statistics

        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{title}</title>
            <link rel="stylesheet" href="assets/styles.css">
          </head>
          <body>
            <div class="container">
              <header>
                <h1>#{title}</h1>
              </header>

              <nav class="sidebar">
                <h2>Navigation</h2>
                <ul>
                  <li><a href="#overview">Overview</a></li>
                  <li><a href="#packages">Packages</a></li>
                  <li><a href="#search">Search</a></li>
                </ul>
              </nav>

              <main class="content">
                <section id="overview">
                  <h2>Overview</h2>
                  <p>This documentation provides comprehensive information about the UML model.</p>

                  <div class="stats-grid">
                    <div class="stat-card">
                      <h3>#{stats[:total_packages]}</h3>
                      <p>Packages</p>
                    </div>
                    <div class="stat-card">
                      <h3>#{stats[:total_classes]}</h3>
                      <p>Classes</p>
                    </div>
                    <div class="stat-card">
                      <h3>#{stats[:total_associations]}</h3>
                      <p>Associations</p>
                    </div>
                    <div class="stat-card">
                      <h3>#{stats[:total_diagrams]}</h3>
                      <p>Diagrams</p>
                    </div>
                  </div>
                </section>

                <section id="packages">
                  <h2>Package Structure</h2>
                  #{build_package_tree_html}
                </section>

                <section id="search">
                  <h2>Search</h2>
                  <div class="search-container">
                    <input type="text" id="search-input" placeholder="Search classes, attributes, associations...">
                    <button id="search-btn">Search</button>
                  </div>
                  <div id="search-results"></div>
                </section>
              </main>
            </div>

            <script src="assets/search.js"></script>
          </body>
          </html>
        HTML
      end

      # Build package tree HTML.
      #
      # @return [String] The package tree HTML
      def build_package_tree_html
        root_path = options[:package] || "ModelRoot"
        tree = repository.package_tree(root_path)
        return "<p>No packages found.</p>" unless tree

        "<div class=\"package-tree\">#{build_tree_node_html(tree)}</div>"
      end

      # Build a tree node HTML recursively.
      #
      # @param node [Hash] The tree node
      # @return [String] HTML representation
      def build_tree_node_html(node)
        path = node[:path]
        link = package_link(path)

        html = "<div class=\"tree-node\">"
        html += "<a href=\"#{link}\">#{node[:name]}</a>"
        html += " <span class=\"count\">(#{node[:classes_count]} classes)</span>" if node[:classes_count].positive?

        if node[:children]&.any?
          html += "<div class=\"tree-children\">"
          node[:children].each do |child|
            html += build_tree_node_html(child)
          end
          html += "</div>"
        end

        html += "</div>"
        html
      end

      # Generate package pages.
      #
      # @return [void]
      def generate_package_pages
        root_path = options[:package] || "ModelRoot"
        packages = repository.list_packages(
          root_path,
          recursive: options.fetch(:recursive, true),
        )

        packages.each do |package|
          generate_package_page(package)
        end
      end

      # Generate a single package page.
      #
      # @param package [Lutaml::Uml::Package, Lutaml::Uml::Document]
      #   The package object
      # @return [void]
      def generate_package_page(package)
        path = package_path(package)
        content = build_package_html(package, path)
        filename = sanitize_filename("#{path}.html")
        File.write(File.join(output_dir, "packages", filename), content)
      end

      # Build package page HTML.
      #
      # @param package [Object] The package object
      # @param path [String] The package path
      # @return [String] The package page HTML
      def build_package_html(package, path)
        title = options.fetch(:title, "UML Model Documentation")
        classes = repository.classes_in_package(path, recursive: false)

        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Package: #{package.name} - #{title}</title>
            <link rel="stylesheet" href="../assets/styles.css">
          </head>
          <body>
            <div class="container">
              <header>
                <h1>Package: #{package.name}</h1>
                <p class="qualified-path"><code>#{path}</code></p>
              </header>

              <nav class="breadcrumb">
                <a href="../index.html">Home</a> / #{build_breadcrumb(path)}
              </nav>

              <main class="content">
                #{"<div class=\"description\">#{package.definition}</div>" if package.definition}

                <h2>Classes</h2>
                #{build_classes_table_html(classes)}

                <p><a href="../index.html">Back to Index</a></p>
              </main>
            </div>
          </body>
          </html>
        HTML
      end

      # Build breadcrumb navigation.
      #
      # @param path [String] The current path
      # @return [String] Breadcrumb HTML
      def build_breadcrumb(path)
        parts = path.split("::")
        breadcrumb = []
        current_path = ""

        parts.each_with_index do |part, index|
          current_path += (current_path.empty? ? "" : "::") + part
          breadcrumb << if index == parts.length - 1
                          "<span>#{part}</span>"
                        else
                          "<a href=\"#{package_link(current_path)}\">#{part}</a>"
                        end
        end

        breadcrumb.join(" / ")
      end

      # Build classes table HTML.
      #
      # @param classes [Array] Array of class objects
      # @return [String] Table HTML
      def build_classes_table_html(classes)
        return "<p>No classes in this package.</p>" if classes.empty?

        html = "<table><thead><tr><th>Name</th><th>Type</th><th>Stereotypes</th><th>Attributes</th></tr></thead><tbody>"

        classes.sort_by(&:name).each do |klass|
          qname = qualified_name(klass)
          link = class_link(qname)
          type = klass.class.name.split("::").last
          stereotypes = format_stereotypes(klass.stereotype)
          attrs_count = klass.attributes&.size || 0

          html += "<tr>"
          html += "<td><a href=\"#{link}\">#{klass.name}</a></td>"
          html += "<td>#{type}</td>"
          html += "<td>#{stereotypes}</td>"
          html += "<td>#{attrs_count}</td>"
          html += "</tr>"
        end

        html += "</tbody></table>"
        html
      end

      # Generate class pages.
      #
      # @return [void]
      def generate_class_pages
        classes = if options[:package]
                    repository.classes_in_package(
                      options[:package],
                      recursive: options.fetch(:recursive, true),
                    )
                  else
                    repository.indexes[:classes].values
                  end

        classes.each do |klass|
          generate_class_page(klass)
        end
      end

      # Generate a single class page.
      #
      # @param klass [Object] The class object
      # @return [void]
      def generate_class_page(klass)
        qname = qualified_name(klass)
        content = build_class_html(klass, qname)
        filename = sanitize_filename("#{qname}.html")
        File.write(File.join(output_dir, "classes", filename), content)
      end

      # Build class page HTML.
      #
      # @param klass [Object] The class object
      # @param qname [String] The qualified name
      # @return [String] The class page HTML
      def build_class_html(klass, qname)
        title = options.fetch(:title, "UML Model Documentation")
        type = klass.class.name.split("::").last
        pkg_path = extract_package_path(qname)

        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{type}: #{klass.name} - #{title}</title>
            <link rel="stylesheet" href="../assets/styles.css">
          </head>
          <body>
            <div class="container">
              <header>
                <h1>#{type}: #{klass.name}</h1>
                <p class="qualified-path"><code>#{qname}</code></p>
              </header>

              <nav class="breadcrumb">
                <a href="../index.html">Home</a> /
                <a href="#{package_link(pkg_path)}">#{pkg_path}</a> /
                <span>#{klass.name}</span>
              </nav>

              <main class="content">
                #{build_stereotypes_html(klass.stereotype)}
                #{"<div class=\"description\">#{klass.definition}</div>" if klass.respond_to?(:definition) && klass.definition}

                #{build_attributes_html(klass)}
                #{build_associations_html(klass)}

                <p><a href="#{package_link(pkg_path)}">Back to Package</a> | <a href="../index.html">Back to Index</a></p>
              </main>
            </div>
          </body>
          </html>
        HTML
      end

      # Build attributes HTML.
      #
      # @param klass [Object] The class object
      # @return [String] Attributes HTML
      def build_attributes_html(klass)
        return "" unless klass.attributes&.any?

        html = "<h2>Attributes</h2><table><thead><tr><th>Name</th><th>Type</th><th>Visibility</th><th>Cardinality</th></tr></thead><tbody>"

        klass.attributes.each do |attr|
          visibility = attr.visibility || ""
          cardinality = format_cardinality(attr.cardinality)
          html += "<tr><td>#{attr.name}</td><td><code>#{attr.type}</code></td><td>#{visibility}</td><td>#{cardinality}</td></tr>"
        end

        html += "</tbody></table>"
        html
      end

      # Build associations HTML.
      #
      # @param klass [Object] The class object
      # @return [String] Associations HTML
      def build_associations_html(klass)
        associations = repository.associations_of(klass)
        return "" if associations.empty?

        html = "<h2>Associations</h2><table><thead><tr><th>Name</th><th>Target</th><th>Cardinality</th><th>Navigable</th></tr></thead><tbody>"

        associations.each do |assoc|
          source_end = assoc.member_end&.first
          target_end = assoc.member_end&.last

          end_obj = if source_end&.type&.xmi_id == klass.xmi_id
                      target_end
                    else
                      source_end
                    end

          next unless end_obj&.type

          target_qname = qualified_name(end_obj.type)
          name = assoc.name || end_obj.name || ""
          cardinality = format_cardinality(end_obj.cardinality)
          navigable = end_obj.navigable? ? "Yes" : "No"

          html += "<tr>"
          html += "<td>#{name}</td>"
          html += "<td><a href=\"#{class_link(target_qname)}\">#{end_obj.type.name}</a></td>"
          html += "<td>#{cardinality}</td>"
          html += "<td>#{navigable}</td>"
          html += "</tr>"
        end

        html += "</tbody></table>"
        html
      rescue StandardError
        ""
      end

      # Generate search index JSON.
      #
      # @return [void]
      def generate_search_index
        classes = repository.indexes[:classes].values

        index = classes.map do |klass|
          qname = qualified_name(klass)
          {
            type: "class",
            name: klass.name,
            qualified_name: qname,
            link: class_link(qname),
            class_type: klass.class.name.split("::").last,
          }
        end

        File.write(
          File.join(output_dir, "assets", "search-index.json"),
          JSON.pretty_generate(index),
        )
      end

      # Copy static assets.
      #
      # @return [void]
      def copy_assets
        generate_stylesheet
        generate_search_script
      end

      # Generate stylesheet.
      #
      # @return [void]
      def generate_stylesheet
        css = File.read(File.join(__dir__, "web_ui", "public", "styles.css"))
        File.write(File.join(output_dir, "assets", "styles.css"), css)
      end

      # Generate search script.
      #
      # @return [void]
      def generate_search_script
        js = <<~JAVASCRIPT
          let searchIndex = [];

          fetch('assets/search-index.json')
            .then(response => response.json())
            .then(data => { searchIndex = data; });

          document.getElementById('search-btn')?.addEventListener('click', performSearch);
          document.getElementById('search-input')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') performSearch();
          });

          function performSearch() {
            const query = document.getElementById('search-input').value.toLowerCase();
            const results = searchIndex.filter(item =>
              item.name.toLowerCase().includes(query) ||
              item.qualified_name.toLowerCase().includes(query)
            );

            displayResults(results, query);
          }

          function displayResults(results, query) {
            const container = document.getElementById('search-results');
            if (results.length === 0) {
              container.innerHTML = '<p>No results found.</p>';
              return;
            }

            let html = `<h3>Results for "${query}"</h3><ul>`;
            results.forEach(item => {
              html += `<li><a href="${item.link}">${item.name}</a> <span class="type">(${item.class_type})</span></li>`;
            });
            html += '</ul>';
            container.innerHTML = html;
          }
        JAVASCRIPT

        File.write(File.join(output_dir, "assets", "search.js"), js)
      end

      # Format cardinality.
      #
      # @param cardinality [Lutaml::Uml::Cardinality, nil] The cardinality
      # @return [String] Formatted cardinality
      def format_cardinality(cardinality)
        return "" unless cardinality

        min = cardinality.min || "0"
        max = cardinality.max || "*"
        "#{min}..#{max}"
      end

      # Get package path.
      #
      # @param package [Object] The package object
      # @return [String] The package path
      def package_path(package)
        repository.indexes[:package_to_path][package.xmi_id] || package.name
      end

      # Get qualified name.
      #
      # @param klass [Object] The class object
      # @return [String] The qualified name
      def qualified_name(klass)
        repository.indexes[:class_to_qname][klass.xmi_id] || klass.name
      end

      # Extract package path from qualified name.
      #
      # @param qname [String] The qualified name
      # @return [String] The package path
      def extract_package_path(qname)
        parts = qname.split("::")
        parts.size > 1 ? parts[0..-2].join("::") : "ModelRoot"
      end

      # Generate package link.
      #
      # @param path [String] The package path
      # @return [String] Relative link
      def package_link(path)
        "../packages/#{sanitize_filename(path)}.html"
      end

      # Generate class link.
      #
      # @param qname [String] The qualified name
      # @return [String] Relative link
      def class_link(qname)
        "../classes/#{sanitize_filename(qname)}.html"
      end

      # Format stereotypes for display.
      #
      # @param stereotype [String, Array, nil] The stereotype value
      # @return [String] Formatted stereotypes string
      def format_stereotypes(stereotype)
        return "" if stereotype.nil?
        return stereotype if stereotype.is_a?(String)
        stereotype.is_a?(Array) ? stereotype.join(", ") : ""
      end

      # Build stereotypes HTML.
      #
      # @param stereotype [String, Array, nil] The stereotype value
      # @return [String] HTML for stereotypes
      def build_stereotypes_html(stereotype)
        return "" if stereotype.nil? || (stereotype.respond_to?(:empty?) && stereotype.empty?)
        
        stereotypes_array = stereotype.is_a?(Array) ? stereotype : [stereotype]
        return "" if stereotypes_array.empty?
        
        formatted = stereotypes_array.map { |s| "<code>#{s}</code>" }.join(', ')
        "<p><strong>Stereotypes:</strong> #{formatted}</p>"
      end

      # Sanitize filename for filesystem compatibility.
      #
      # @param name [String] The filename
      # @return [String] Sanitized filename
      def sanitize_filename(name)
        name.gsub("::", "_").gsub(/[^a-zA-Z0-9_\-.]/, "_")
      end
    end
  end
end
