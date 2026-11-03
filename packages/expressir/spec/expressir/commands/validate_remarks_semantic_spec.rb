# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Commands::ValidateRemarks do
  def violations_for(content, files = {})
    Dir.mktmpdir("remarks-semantic") do |dir|
      path = File.join(dir, "sample.exp")
      File.write(path, content)
      files.each { |name, body| File.write(File.join(dir, name), body) }
      errors = nil
      begin
        described_class.new({}).run([path])
      rescue Expressir::SchemaValidationError => e
        errors = e.errors
      end
      errors || []
    end
  end

  describe "returned-LOCAL descriptions" do
    it "reports a described LOCAL referenced in RETURN" do
      errors = violations_for(<<~EXPRESS)
        SCHEMA sample;
        FUNCTION f(a : INTEGER) : INTEGER;
          LOCAL
            n : INTEGER := 0;
          END_LOCAL;
          n := a;
          RETURN (n);
          (*"sample.f.n"
          (output) the count
          *)
        END_FUNCTION;
        END_SCHEMA;
      EXPRESS
      expect(errors.join).to include(
        "describe the result in the body of the FUNCTION description",
      )
      expect(errors.join).to include("LOCAL variable `n`")
    end

    it "reports a described LOCAL whose RETURN is nested in an IF" do
      errors = violations_for(<<~EXPRESS)
        SCHEMA sample;
        FUNCTION f(a : INTEGER) : INTEGER;
          LOCAL
            n : INTEGER := 0;
          END_LOCAL;
          n := a;
          IF a > 0 THEN
            RETURN (n);
          END_IF;
          RETURN (a);
          (*"sample.f.n"
          (output) the count
          *)
        END_FUNCTION;
        END_SCHEMA;
      EXPRESS
      expect(errors.join).to include("LOCAL variable `n`")
    end

    it "passes when the described LOCAL is not referenced in RETURN" do
      expect(violations_for(<<~EXPRESS)).to be_empty
        SCHEMA sample;
        FUNCTION f(a : INTEGER) : INTEGER;
          LOCAL
            n : INTEGER := 0;
          END_LOCAL;
          n := a;
          RETURN (a);
          (*"sample.f.n"
          (intermediate) the counter
          *)
        END_FUNCTION;
        END_SCHEMA;
      EXPRESS
    end
  end

  describe "svgmap list items" do
    let(:svg) do
      <<~SVG
        <svg><a href="1"><rect/></a><a href="3"><rect/></a></svg>
      SVG
    end

    it "reports unknown schemas, ordinals with no hyperlink, and " \
       "unclaimed hyperlinks" do
      errors = violations_for(<<~EXPRESS, "probe.svg" => svg)
        SCHEMA sample;
        ENTITY a; END_ENTITY;
        (*"sample.__expressg"
        [.svgmap]
        ====
        image::probe.svg[]

        * <<express:missing_schema>>; 1
        * <<express:sample.a>>; 2
        ====
        *)
        END_SCHEMA;
      EXPRESS
      joined = errors.join
      expect(joined).to include("not declared in the repository")
      expect(joined).to include("ordinal `2` has no hyperlink")
      expect(joined).to include("hyperlink `3`")
    end

    it "reports the ordinal placed inside the cross-reference" do
      errors = violations_for(<<~EXPRESS, "sample.svg" => svg)
        SCHEMA sample;
        ENTITY a; END_ENTITY;
        (*"sample.__expressg"
        [.svgmap]
        ====
        image::sample.svg[]

        * <<express:other.a; 1>>
        ====
        *)
        END_SCHEMA;
      EXPRESS
      expect(errors.join).to include(
        "places the ordinal inside the cross-reference",
      )
    end

    it "passes a consistent block" do
      consistent_svg = <<~SVG
        <svg><a href="1"><rect/></a></svg>
      SVG
      content = <<~EXPRESS
        SCHEMA sample;
        ENTITY a; END_ENTITY;
        (*"sample.__expressg"
        [.svgmap]
        ====
        image::sample.svg[]

        * <<express:sample.a>>; 1
        ====
        *)
        END_SCHEMA;
      EXPRESS
      expect(violations_for(content, "sample.svg" => consistent_svg))
        .to be_empty
    end
  end
end
