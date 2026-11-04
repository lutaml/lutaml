# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/html_document_builder"

RSpec.describe Lutaml::Xsd::Spa::HtmlDocumentBuilder do
  subject(:builder) { described_class.new }

  describe "#initialize" do
    it "sets default options" do
      expect(builder.options[:lang]).to eq("en")
      expect(builder.options[:charset]).to eq("UTF-8")
      expect(builder.options[:title]).to eq("Document")
    end

    it "accepts custom options" do
      builder = described_class.new(title: "Custom Title", lang: "ja")
      expect(builder.options[:title]).to eq("Custom Title")
      expect(builder.options[:lang]).to eq("ja")
    end
  end

  describe "#title" do
    it "sets document title" do
      builder.title("Test Document")
      expect(builder.options[:title]).to eq("Test Document")
    end

    it "returns self for method chaining" do
      result = builder.title("Test")
      expect(result).to eq(builder)
    end
  end

  describe "#language" do
    it "sets document language" do
      builder.language("ja")
      expect(builder.options[:lang]).to eq("ja")
    end

    it "returns self for method chaining" do
      result = builder.language("ja")
      expect(result).to eq(builder)
    end
  end

  describe "#meta_tag" do
    it "adds meta tag" do
      builder.meta_tag("description", "Test description")
      html = builder.build

      expect(html).to include('<meta name="description" content="Test description">')
    end

    it "returns self for method chaining" do
      result = builder.meta_tag("author", "Test Author")
      expect(result).to eq(builder)
    end
  end

  describe "#charset" do
    it "sets charset" do
      builder.charset("ISO-8859-1")
      expect(builder.options[:charset]).to eq("ISO-8859-1")
    end

    it "uses UTF-8 by default" do
      builder.charset
      expect(builder.options[:charset]).to eq("UTF-8")
    end

    it "returns self for method chaining" do
      result = builder.charset("UTF-8")
      expect(result).to eq(builder)
    end
  end

  describe "#viewport" do
    it "sets viewport content" do
      builder.viewport("width=1024")
      expect(builder.options[:viewport]).to eq("width=1024")
    end

    it "uses default viewport if not specified" do
      builder.viewport
      expect(builder.options[:viewport]).to eq("width=device-width, initial-scale=1.0")
    end

    it "returns self for method chaining" do
      result = builder.viewport
      expect(result).to eq(builder)
    end
  end

  describe "#external_stylesheet" do
    it "adds external stylesheet link" do
      builder.external_stylesheet("styles.css")
      html = builder.build

      expect(html).to include('<link rel="stylesheet" href="styles.css">')
    end

    it "returns self for method chaining" do
      result = builder.external_stylesheet("styles.css")
      expect(result).to eq(builder)
    end
  end

  describe "#inline_style" do
    it "adds inline style content" do
      builder.inline_style("body { margin: 0; }")
      html = builder.build

      expect(html).to include("<style>")
      expect(html).to include("body { margin: 0; }")
    end

    it "returns self for method chaining" do
      result = builder.inline_style("body { margin: 0; }")
      expect(result).to eq(builder)
    end
  end

  describe "#external_script" do
    it "adds external script" do
      builder.external_script("app.js")
      html = builder.build

      expect(html).to include('src="app.js"')
    end

    it "adds script with defer option" do
      builder.external_script("app.js", defer: true)
      html = builder.build

      expect(html).to include("defer")
    end

    it "adds script with async option" do
      builder.external_script("app.js", async: true)
      html = builder.build

      expect(html).to include("async")
    end

    it "adds script with module option" do
      builder.external_script("app.js", module: true)
      html = builder.build

      expect(html).to include('type="module"')
    end

    it "returns self for method chaining" do
      result = builder.external_script("app.js")
      expect(result).to eq(builder)
    end
  end

  describe "#inline_script" do
    it "adds inline script content" do
      builder.inline_script("console.log('test');")
      html = builder.build

      expect(html).to include("<script>")
      expect(html).to include("console.log('test');")
    end

    it "adds inline script with module option" do
      builder.inline_script("export default {};", module: true)
      html = builder.build

      expect(html).to include('<script type="module">')
    end

    it "returns self for method chaining" do
      result = builder.inline_script("console.log('test');")
      expect(result).to eq(builder)
    end
  end

  describe "#body_class" do
    it "adds body class" do
      builder.body_class("dark-theme")
      html = builder.build

      expect(html).to include('<body class="dark-theme">')
    end

    it "adds multiple body classes" do
      builder.body_class("theme-dark").body_class("responsive")
      html = builder.build

      expect(html).to include('class="theme-dark responsive"')
    end

    it "returns self for method chaining" do
      result = builder.body_class("test")
      expect(result).to eq(builder)
    end
  end

  describe "#body_attribute" do
    it "adds body attribute" do
      builder.body_attribute("data-version", "1.0")
      html = builder.build

      expect(html).to include('data-version="1.0"')
    end

    it "returns self for method chaining" do
      result = builder.body_attribute("data-test", "value")
      expect(result).to eq(builder)
    end
  end

  describe "#head_content" do
    it "adds custom head content" do
      builder.head_content("<!-- Custom comment -->")
      html = builder.build

      expect(html).to include("<!-- Custom comment -->")
    end

    it "returns self for method chaining" do
      result = builder.head_content("<!-- test -->")
      expect(result).to eq(builder)
    end
  end

  describe "#body_content" do
    it "sets body content" do
      builder.body_content("<h1>Hello</h1>")
      html = builder.build

      expect(html).to include("<h1>Hello</h1>")
    end

    it "returns self for method chaining" do
      result = builder.body_content("<p>test</p>")
      expect(result).to eq(builder)
    end
  end

  describe "#theme" do
    it "adds data-theme attribute to body" do
      builder.theme("dark")
      html = builder.build

      expect(html).to include('data-theme="dark"')
    end

    it "returns self for method chaining" do
      result = builder.theme("dark")
      expect(result).to eq(builder)
    end
  end

  describe "#build" do
    it "returns complete HTML document" do
      html = builder.build

      expect(html).to start_with("<!DOCTYPE html>")
      expect(html).to include("<html")
      expect(html).to include("<head>")
      expect(html).to include("</head>")
      expect(html).to include("<body")
      expect(html).to include("</body>")
      expect(html).to end_with("</html>")
    end

    it "includes DOCTYPE declaration" do
      html = builder.build
      expect(html).to start_with("<!DOCTYPE html>")
    end

    it "includes html tag with language" do
      builder.language("ja")
      html = builder.build

      expect(html).to include('<html lang="ja">')
    end

    it "includes charset meta tag" do
      html = builder.build
      expect(html).to include('<meta charset="UTF-8">')
    end

    it "includes viewport meta tag" do
      html = builder.build
      expect(html).to include('<meta name="viewport"')
    end

    it "includes generator meta tag" do
      html = builder.build
      expect(html).to include('<meta name="generator" content="lutaml-xsd')
    end

    it "includes title tag" do
      builder.title("Test Page")
      html = builder.build

      expect(html).to include("<title>Test Page</title>")
    end

    it "escapes HTML in title" do
      builder.title("<script>alert('xss')</script>")
      html = builder.build

      expect(html).to include("&lt;script&gt;")
      expect(html).not_to include("<script>alert")
    end
  end

  describe "#reset" do
    it "resets builder state" do
      builder
        .title("Old Title")
        .body_class("old-class")
        .body_content("<p>Old content</p>")

      builder.reset

      html = builder.build
      expect(html).not_to include("Old Title")
      expect(html).not_to include("old-class")
      expect(html).not_to include("Old content")
    end

    it "preserves specified options after reset" do
      builder = described_class.new(lang: "ja")
      builder.title("Test").body_content("<p>Test</p>")

      builder.reset

      expect(builder.options[:lang]).to eq("ja")
    end

    it "returns self for method chaining" do
      result = builder.reset
      expect(result).to eq(builder)
    end
  end

  describe "method chaining" do
    it "supports fluent interface" do
      html = builder
        .title("Chained Title")
        .language("en")
        .meta_tag("description", "Test")
        .viewport("width=1024")
        .external_stylesheet("styles.css")
        .inline_style("body { margin: 0; }")
        .body_class("container")
        .body_content("<h1>Content</h1>")
        .build

      expect(html).to include("Chained Title")
      expect(html).to include('lang="en"')
      expect(html).to include("styles.css")
    end
  end

  describe "edge cases" do
    it "handles empty body content" do
      html = builder.build
      expect(html).to include("<body")
      expect(html).to include("</body>")
    end

    it "handles nil values gracefully" do
      builder.title(nil)
      html = builder.build

      expect(html).to include("<title></title>")
    end

    it "handles special characters in content" do
      builder.body_content("<div>Special: &<>\"'</div>")
      html = builder.build

      expect(html).to include("<div>Special: &<>\"'</div>")
    end

    it "handles multiple stylesheets" do
      builder
        .external_stylesheet("reset.css")
        .external_stylesheet("main.css")
        .external_stylesheet("theme.css")

      html = builder.build
      expect(html).to include("reset.css")
      expect(html).to include("main.css")
      expect(html).to include("theme.css")
    end

    it "handles multiple inline styles" do
      builder
        .inline_style("body { margin: 0; }")
        .inline_style("h1 { color: blue; }")

      html = builder.build
      expect(html).to include("body { margin: 0; }")
      expect(html).to include("h1 { color: blue; }")
    end

    it "handles multiple scripts" do
      builder
        .external_script("jquery.js")
        .external_script("app.js", defer: true)
        .inline_script("console.log('ready');")

      html = builder.build
      expect(html).to include("jquery.js")
      expect(html).to include("app.js")
      expect(html).to include("console.log('ready');")
    end
  end

  describe "HTML validity" do
    it "produces well-formed HTML structure" do
      html = builder
        .title("Valid HTML")
        .body_content("<div><p>Test</p></div>")
        .build

      expect(html.scan("<html").size).to eq(1)
      expect(html.scan("</html>").size).to eq(1)
      expect(html.scan("<head>").size).to eq(1)
      expect(html.scan("</head>").size).to eq(1)
      expect(html.scan("<body").size).to eq(1)
      expect(html.scan("</body>").size).to eq(1)
    end

    it "properly indents content" do
      html = builder.build
      lines = html.split("\n")

      expect(lines.first).to eq("<!DOCTYPE html>")
      expect(lines).to include('  <meta charset="UTF-8">')
    end
  end
end
