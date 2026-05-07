# frozen_string_literal: true

require "spec_helper"
require "liquid"
require_relative "../../../../lib/lutaml/uml_repository/static_site/generator"

RSpec.describe Lutaml::UmlRepository::StaticSite::TemplateFileSystem do
  subject(:file_system) { described_class.new(template_root) }

  let(:template_root) do
    File.expand_path("../../../../templates/static_site", __dir__)
  end

  describe "#initialize" do
    it "stores the root path" do
      expect(file_system.root).to eq(template_root)
    end
  end

  describe "#read_template_file" do
    it "resolves component includes without underscore prefix" do
      content = file_system.read_template_file("components/header")
      expect(content).to include("<header")
    end

    it "resolves sidebar component" do
      content = file_system.read_template_file("components/sidebar")
      expect(content).to include("<aside")
    end

    it "resolves content component" do
      content = file_system.read_template_file("components/content")
      expect(content).to include("content-area")
    end

    it "resolves tree_node component with self-referencing include" do
      content = file_system.read_template_file("components/tree_node")
      expect(content).to include("tree-node")
    end

    it "raises Liquid::FileSystemError for path traversal attempts" do
      expect { file_system.read_template_file("../../etc/passwd") }
        .to raise_error(Liquid::FileSystemError, /Illegal template path/)
    end

    it "raises Errno::ENOENT for missing templates" do
      expect { file_system.read_template_file("nonexistent") }
        .to raise_error(Errno::ENOENT)
    end
  end

  describe "Liquid integration" do
    it "renders a template with {% include %} directives" do
      template_source = <<~LIQUID
        <div>
          {% include 'components/header' %}
        </div>
      LIQUID
      template = Liquid::Template.parse(template_source)
      template.registers[:file_system] = file_system

      html = template.render("config" => '{"title":"Test"}')

      expect(html).not_to include("Liquid error")
      expect(html).to include("<header")
      expect(html).to include("app-header")
    end

    it "renders all three includes from multi_file template" do
      template_path = File.join(template_root, "multi_file.liquid")
      template = Liquid::Template.parse(File.read(template_path))
      template.registers[:file_system] = file_system

      context = {
        "config" => '{"title":"Test","mode":"multi_file"}',
        "data" => nil,
        "searchIndex" => nil,
        "buildInfo" => { "timestamp" => Time.now.utc.iso8601,
                         "generator" => "Test" },
      }
      html = template.render(context)

      expect(html).not_to include("Liquid error")
      expect(html).to include("<header")
      expect(html).to include("<aside")
      expect(html).to include("content-area")
    end
  end
end
