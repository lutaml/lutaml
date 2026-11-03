# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Express::Listing do
  def parse_schemas(sources)
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path),
                                                       skip_references: true)
    schemas = repository.schemas.compact
    files.each(&:unlink)
    schemas
  end

  let(:schemas) do
    parse_schemas(
      "support" => <<~EXP,
        SCHEMA support;
        TYPE label = STRING; END_TYPE;
        ENTITY thing;
          name : STRING;
        END_ENTITY;
        END_SCHEMA;
      EXP
      "root" => <<~EXP,
        SCHEMA root;
        USE FROM support (label, thing);
        TYPE identifier = label; END_TYPE;
        ENTITY person;
          id : identifier;
        WHERE
          WR1: TRUE;
        END_ENTITY;
        FUNCTION foo : BOOLEAN;
          RETURN (TRUE);
        END_FUNCTION;
        END_SCHEMA;
      EXP
    )
  end

  describe ".list" do
    it "emits SCHEMA header, counts, interfaces, and SCHEMA.name declarations" do
      text = described_class.list(schemas)
      aggregate_failures do
        expect(text).to match(/^SCHEMA root;/)
        expect(text).to match(/^SCHEMA support;/)
        expect(text).to include("USE FROM support(...)")
        expect(text).to include("TYPE root.identifier;")
        expect(text).to include("ENTITY root.person;")
        expect(text).to include("FUNCTION root.foo;")
        expect(text).to match(/\(\* TYPE\s+1 \*\)/)
        expect(text).to match(/\(\* ENTITY\s+1 \*\)/)
      end
    end
  end

  describe ".smrl_xml" do
    it "wraps schemas in concatenated_express_file_content_list" do
      text = described_class.smrl_xml(schemas, source: "fixture.exp")
      aggregate_failures do
        expect(text).to include("<concatenated_express_file_content_list>")
        expect(text).to include("</concatenated_express_file_content_list>")
        expect(text).to include("<schema>root</schema>")
        expect(text).to include("<schema>support</schema>")
        expect(text).to include("<use-from>support(...)</use-from>")
        expect(text).to include("<type>root.identifier</type>")
        expect(text).to include("<entity>root.person</entity>")
        expect(text).to include("<function>root.foo</function>")
        expect(text).to include("<!-- File: fixture.exp -->")
      end
    end
  end
end
