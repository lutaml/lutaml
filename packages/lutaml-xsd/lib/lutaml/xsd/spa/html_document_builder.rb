# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      # HTML document builder (Builder Pattern)
      #
      # Provides a fluent interface for building complete HTML documents with
      # proper structure, meta tags, styles, and scripts. This builder separates
      # the construction of a complex HTML document from its representation.
      #
      # @example Build a single-file HTML document
      #   builder = HtmlDocumentBuilder.new
      #   html = builder
      #     .title("My Schema")
      #     .meta_tag("description", "Schema documentation")
      #     .inline_style(css_content)
      #     .inline_script(js_content)
      #     .body_content(main_content)
      #     .build
      #
      # @example Build a multi-file HTML document
      #   builder = HtmlDocumentBuilder.new
      #   html = builder
      #     .title("My Schema")
      #     .external_stylesheet("css/styles.css")
      #     .external_script("js/app.js")
      #     .body_content(main_content)
      #     .build
      class HtmlDocumentBuilder
        attr_reader :options

        # Initialize HTML document builder
        #
        # @param options [Hash] Initial options
        def initialize(options = {})
          @options = default_options.merge(options)
          @meta_tags = []
          @stylesheets = []
          @inline_styles = []
          @scripts = []
          @inline_scripts = []
          @body_classes = []
          @body_attributes = {}
          @head_content = []
          @body_content = ""
        end

        # Set document title
        #
        # @param value [String] Document title
        # @return [self] Builder instance for chaining
        def title(value)
          @options[:title] = value
          self
        end

        # Set document language
        #
        # @param value [String] Language code (e.g., "en", "ja")
        # @return [self] Builder instance for chaining
        def language(value)
          @options[:lang] = value
          self
        end

        # Add meta tag
        #
        # @param name [String] Meta tag name
        # @param content [String] Meta tag content
        # @return [self] Builder instance for chaining
        def meta_tag(name, content)
          @meta_tags << { name: name, content: content }
          self
        end

        # Add charset meta tag
        #
        # @param charset [String] Character encoding (default: UTF-8)
        # @return [self] Builder instance for chaining
        def charset(charset = "UTF-8")
          @options[:charset] = charset
          self
        end

        # Add viewport meta tag
        #
        # @param content [String] Viewport content
        # @return [self] Builder instance for chaining
        def viewport(content = "width=device-width, initial-scale=1.0")
          @options[:viewport] = content
          self
        end

        # Add external stylesheet link
        #
        # @param href [String] Stylesheet URL
        # @return [self] Builder instance for chaining
        def external_stylesheet(href)
          @stylesheets << href
          self
        end

        # Add inline style content
        #
        # @param css [String] CSS content
        # @return [self] Builder instance for chaining
        def inline_style(css)
          @inline_styles << css
          self
        end

        # Add external script
        #
        # @param src [String] Script URL
        # @param options [Hash] Script options (defer, async, module)
        # @return [self] Builder instance for chaining
        def external_script(src, options = {})
          @scripts << { src: src, options: options }
          self
        end

        # Add inline script content
        #
        # @param js [String] JavaScript content
        # @param options [Hash] Script options
        # @return [self] Builder instance for chaining
        def inline_script(js, options = {})
          @inline_scripts << { content: js, options: options }
          self
        end

        # Add body class
        #
        # @param class_name [String] CSS class name
        # @return [self] Builder instance for chaining
        def body_class(class_name)
          @body_classes << class_name
          self
        end

        # Add body attribute
        #
        # @param name [String] Attribute name
        # @param value [String] Attribute value
        # @return [self] Builder instance for chaining
        def body_attribute(name, value)
          @body_attributes[name] = value
          self
        end

        # Add content to head section
        #
        # @param content [String] HTML content for head
        # @return [self] Builder instance for chaining
        def head_content(content)
          @head_content << content
          self
        end

        # Set body content
        #
        # @param content [String] HTML content for body
        # @return [self] Builder instance for chaining
        def body_content(content)
          @body_content = content
          self
        end

        # Set theme (adds data-theme attribute to body)
        #
        # @param theme [String] Theme name (e.g., "light", "dark")
        # @return [self] Builder instance for chaining
        def theme(theme)
          body_attribute("data-theme", theme)
          self
        end

        # Build complete HTML document
        #
        # @return [String] Complete HTML document
        def build
          parts = []
          parts << doctype
          parts << html_open_tag
          parts << build_head
          parts << build_body
          parts << html_close_tag
          parts.join("\n")
        end

        # Reset builder to initial state
        #
        # @return [self] Builder instance for chaining
        def reset
          initialize(@options.slice(:lang, :charset, :viewport))
          self
        end

        private

        # Default options
        #
        # @return [Hash] Default options
        def default_options
          {
            lang: "en",
            charset: "UTF-8",
            viewport: "width=device-width, initial-scale=1.0",
            title: "Document",
            generator: "lutaml-xsd v#{Lutaml::Xsd::VERSION}",
          }
        end

        # Build DOCTYPE declaration
        #
        # @return [String] DOCTYPE
        def doctype
          "<!DOCTYPE html>"
        end

        # Build opening HTML tag
        #
        # @return [String] HTML opening tag
        def html_open_tag
          %(<html lang="#{@options[:lang]}">)
        end

        # Build closing HTML tag
        #
        # @return [String] HTML closing tag
        def html_close_tag
          "</html>"
        end

        # Build head section
        #
        # @return [String] Complete head section
        def build_head
          parts = ["<head>"]
          parts << build_meta_tags
          parts << build_title
          parts << build_stylesheets
          parts << build_inline_styles
          parts += @head_content
          parts << "</head>"
          parts.join("\n  ")
        end

        # Build meta tags
        #
        # @return [String] Meta tags HTML
        def build_meta_tags
          tags = []
          tags << %(<meta charset="#{@options[:charset]}">)
          tags << %(<meta name="viewport" content="#{@options[:viewport]}">)
          tags << %(<meta name="generator" content="#{@options[:generator]}">)

          @meta_tags.each do |meta|
            tags << %(<meta name="#{meta[:name]}" content="#{meta[:content]}">)
          end

          tags.join("\n  ")
        end

        # Build title tag
        #
        # @return [String] Title tag HTML
        def build_title
          "<title>#{escape_html(@options[:title])}</title>"
        end

        # Build stylesheet links
        #
        # @return [String] Stylesheet links HTML
        def build_stylesheets
          return "" if @stylesheets.empty?

          @stylesheets.map do |href|
            %(<link rel="stylesheet" href="#{href}">)
          end.join("\n  ")
        end

        # Build inline styles
        #
        # @return [String] Inline styles HTML
        def build_inline_styles
          return "" if @inline_styles.empty?

          styles = @inline_styles.join("\n\n")
          "  <style>\n#{indent(styles, 4)}\n  </style>"
        end

        # Build body section
        #
        # @return [String] Complete body section
        def build_body
          attrs = build_body_attributes
          parts = ["<body#{attrs}>"]
          parts << @body_content
          parts << build_scripts unless @scripts.empty? && @inline_scripts.empty?
          parts << "</body>"
          parts.join("\n")
        end

        # Build body tag attributes
        #
        # @return [String] Body attributes string
        def build_body_attributes
          attrs = []

          attrs << %(class="#{@body_classes.join(' ')}") unless @body_classes.empty?

          @body_attributes.each do |name, value|
            attrs << %(#{name}="#{value}")
          end

          attrs.empty? ? "" : " #{attrs.join(' ')}"
        end

        # Build script tags
        #
        # @return [String] Script tags HTML
        def build_scripts
          parts = []

          # External scripts
          @scripts.each do |script|
            attrs = [%(src="#{script[:src]}")]
            attrs << "defer" if script[:options][:defer]
            attrs << "async" if script[:options][:async]
            attrs << 'type="module"' if script[:options][:module]
            parts << "<script #{attrs.join(' ')}></script>"
          end

          # Inline scripts
          @inline_scripts.each do |script|
            attrs = []
            attrs << 'type="module"' if script[:options][:module]
            tag_attrs = attrs.empty? ? "" : " #{attrs.join(' ')}"
            parts << "<script#{tag_attrs}>\n#{indent(script[:content],
                                                     2)}\n</script>"
          end

          parts.join("\n")
        end

        # Escape HTML special characters
        #
        # @param text [String] Text to escape
        # @return [String] Escaped text
        def escape_html(text)
          text.to_s
            .gsub("&", "&amp;")
            .gsub("<", "&lt;")
            .gsub(">", "&gt;")
            .gsub('"', "&quot;")
            .gsub("'", "&#39;")
        end

        # Indent text
        #
        # @param text [String] Text to indent
        # @param spaces [Integer] Number of spaces
        # @return [String] Indented text
        def indent(text, spaces)
          prefix = " " * spaces
          text.split("\n").map { |line| "#{prefix}#{line}" }.join("\n")
        end
      end
    end
  end
end
