# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# expressir#125: statements that qualify items with the CURRENT schema's
# name (`'AIC_X.B_SPLINE_SURFACE'` inside AIC_X) are technically incorrect
# — the prefix names the local schema while the item comes from elsewhere
# (imported implicitly through a USEd supertype). The Checker warns with
# the true defining schema; the fixer rewrites the literal.
RSpec.describe Expressir::Express::SelfSchemaReference do
  def parse_repository(sources)
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(
      files.map(&:path), skip_references: true
    )
    [repository, files]
  end

  let(:sources) do
    {
      "geometry" => <<~EXP,
        SCHEMA geometry_schema;
        ENTITY b_spline_curve;
          self_index : STRING;
        END_ENTITY;
        ENTITY b_spline_surface;
          y : STRING;
        END_ENTITY;
        ENTITY elementary_surface;
          z : STRING;
        END_ENTITY;
        TYPE bottom_curve = b_spline_curve; END_TYPE;
        END_SCHEMA;
      EXP
      "aic" => <<~EXP,
        SCHEMA aic_topologically_bounded_surface;
        USE FROM geometry_schema (
          b_spline_curve_with_knots,
          b_spline_surface,
          elementary_surface );
        ENTITY advanced_face;
          face_geometry : elementary_surface;
        WHERE
          WR1 : SIZEOF(['AIC_TOPOLOGICALLY_BOUNDED_SURFACE.ELEMENTARY_SURFACE',
                        'AIC_TOPOLOGICALLY_BOUNDED_SURFACE.B_SPLINE_SURFACE'] *
                       TYPEOF(face_geometry)) = 1;
        END_ENTITY;
        END_SCHEMA;
      EXP
    }
  end

  it "detects self-schema-qualified literals with their true source" do
    repository, @files = parse_repository(sources)
    aic = repository.schemas.find { |s| s.id.start_with?("aic_") }

    matches = described_class.matches(aic)
    items = matches.map { |x| x.item.downcase }
    aggregate_failures do
      expect(items).to include("elementary_surface", "b_spline_surface")
      expect(matches.filter_map(&:source_schema).map(&:id).uniq)
        .to eq(["geometry_schema"])
    end
  end

  it "rewrites the prefix to the true defining schema on fix!" do
    repository, @files = parse_repository(sources)
    aic = repository.schemas.find { |s| s.id.start_with?("aic_") }

    count = described_class.fix!(aic)
    expect(count).to eq(2)

    text = Expressir::Express::Formatter.format(aic)
    aggregate_failures do
      expect(text).to include("geometry_schema.ELEMENTARY_SURFACE")
      expect(text).to include("geometry_schema.B_SPLINE_SURFACE")
      expect(text).not_to include("AIC_TOPOLOGICALLY_BOUNDED_SURFACE.")
    end
  end

  it "Checker warns as check-self-schema-reference" do
    repository, @files = parse_repository(sources)
    result = Expressir::Express::Checker.new(repository).check
    notes = result.warnings.select { |n| n.id == :check_self_schema_reference }
    expect(notes.size).to eq(2)
  end
end
