# frozen_string_literal: true

require 'spec_helper'
require 'svg_conform'

# Issue #52: gate generated diagram output through svg_conform. Every
# full-document RS 3001 corpus fixture is rendered by the ELK engine and
# validated against the SVG base profile, so engine regressions surface
# as spec failures instead of broken user output.
RSpec.describe 'generated diagram conformance', :svg_conform do
  fixtures = Dir[File.expand_path('../../fixtures/rs3001/*.lml', __dir__)].sort

  it 'has corpus fixtures to check' do
    expect(fixtures).not_to be_empty
  end

  fixtures.each do |path|
    it "renders #{File.basename(path)} as a conforming SVG" do
      document = Lutaml::Lml.parse_document(StringIO.new(File.read(path)))
      svg = Lutaml::Formatter::Elk.new.format(document)
      report = SvgConform.validate(svg, profile: :base)
      unless report.valid?
        detail = report.errors.first(3).map(&:message).join('; ')
        raise "non-conforming output: #{detail}"
      end
    end
  end
end
