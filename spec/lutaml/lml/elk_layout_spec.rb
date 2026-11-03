# frozen_string_literal: true

require 'spec_helper'
require 'rexml/document'
require 'stringio'

RSpec.describe 'ELK diagram layout', :skip_unless_elkrb do
  describe 'output formats' do
    it 'converts the diagram to PS through vectory' do
      formatter = Lutaml::Formatter::Elk.new
      formatter.type = :ps
      expect(formatter.format(document)).to start_with('%!PS-Adobe')
    end
  end

  let(:document) do
    Lutaml::Lml.parse_document(StringIO.new(<<~LML))
      class Glaze {
        attribute color, String
      }
      class Tile { }
      association {
        owner_type aggregation
        owner Tile
        member_type association
        member Glaze
      }
    LML
  end

  let(:svg) { Lutaml::Formatter::Elk.new.format(document) }

  it 'positions every node with positive coordinates' do
    graph = Lutaml::Layout::ElkGraphBuilder.new.build(document)
    Lutaml::Layout::ElkEngine.new(input: graph).render(:svg)
    expect(graph.children.map { |n| [n.x.to_f, n.y.to_f] })
      .to all(include(be > 0))
  end

  it 'builds a node per classifier with member labels' do
    graph = Lutaml::Layout::ElkGraphBuilder.new.build(document)
    glaze = graph.children.find { |n| n.id == 'Glaze' }
    expect(glaze.labels.map(&:text)).to eq(['Glaze', '+ color: String'])
    expect(graph.edges.size).to eq(1)
  end

  it 'emits well-formed SVG containing nodes and edges' do
    xml = REXML::Document.new(svg)
    expect(xml.get_elements('//rect').size).to eq(2)
    expect(xml.get_elements('//polyline').size).to eq(1)
  end

  it 'raises on unsupported output types' do
    formatter = Lutaml::Formatter::Elk.new
    expect { formatter.type = :png }.to raise_error(ArgumentError, /unsupported output type/)
  end

  it 'escapes markup-sensitive label text' do
    doc = Lutaml::Lml.parse_document(StringIO.new("class A {\n  definition \"uses <B> markup\"\n}\n"))
    svg = Lutaml::Formatter::Elk.new.format(doc)
    expect(svg).not_to include('<B>')
    expect(svg).to include('&lt;B&gt;')
  end
end
