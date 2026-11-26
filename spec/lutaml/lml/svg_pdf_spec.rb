# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

# Issue #53: direct PDF output for ELK-layout diagrams through pdfrb,
# with no external tools. The ELK SVG shape (rounded node rects, text
# labels, polyline edges, arrow markers) is re-emitted through pdfrb's
# Canvas; the font resources are pdfrb's in-gem base-14 metrics.
RSpec.describe Lutaml::Formatter::SvgPdf do
  let(:document) do
    Lutaml::Lml.parse_document(StringIO.new(<<~LML))
      class Glaze {
        attribute color, String
      }
      class Tile {
        attribute width, Integer
      }
      association {
        owner_type aggregation
        owner Tile
        member_type association
        member Glaze
      }
    LML
  end

  let(:svg) { Lutaml::Formatter::Elk.new.format(document) }

  subject(:pdf) { described_class.new(svg).render }

  it 'emits a PDF byte stream' do
    expect(pdf).to start_with('%PDF-1.')
  end

  it 'produces a structurally valid single-page document' do
    require 'pdfrb'
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'diagram.pdf')
      File.binwrite(path, pdf)
      doc = Pdfrb.open(path)
      expect(Pdfrb::Validator.validate(doc)).to be_empty
      expect(doc.catalog.pages.count).to eq(1)
    end
  end
end

RSpec.describe Lutaml::Formatter::Elk do
  let(:document) do
    Lutaml::Lml.parse_document(StringIO.new(<<~LML))
      class Glaze { }
      class Tile { }
      association {
        owner_type aggregation
        owner Tile
        member_type association
        member Glaze
      }
    LML
  end

  it 'accepts :pdf as an output type' do
    formatter = described_class.new
    formatter.type = :pdf
    expect(formatter.format(document)).to start_with('%PDF-1.')
  end

  it 'keeps vectory types working alongside pdf' do
    formatter = described_class.new
    formatter.type = :ps
    expect(formatter.format(document)).to start_with('%!PS-Adobe')
  end
end
