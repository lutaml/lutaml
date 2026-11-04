# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "moxml"

# TODO.p28/05: the clause 8 configuration over the clause 7 default
# binding. The end-to-end invariant: a configuration with no
# directives derives the default binding byte-for-byte, so the
# TODO.p28/01-04 corpus validates through a configured derivation;
# naming-convention, renames and the target namespace apply per
# clause 8; directives outside the derivation's applied subset are
# registered divergence D-04.
RSpec.describe Expressir::P28::Configuration do
  def parse_express(text)
    Expressir::Express::Parser.from_exp(text).schemas.first
  end

  # The TODO.p28/03 corpus schema (values_demo) — defined types,
  # enumerations, aggregates, entity references.
  let(:values_demo) do
    parse_express(<<~EXPRESS)
      SCHEMA values_demo;
        TYPE colour = ENUMERATION OF (red, green);
      END_TYPE;
        ENTITY box;
          label : STRING;
          count : INTEGER;
          hue : colour;
          bits : BINARY;
          tags : LIST [1:?] OF STRING;
        END_ENTITY;
        ENTITY widget;
          size : box;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  # A second corpus schema: supertype closure over renamed attributes.
  let(:shaped) do
    parse_express(<<~EXPRESS)
      SCHEMA shaped;
        ENTITY base_thing;
          base_label : STRING;
        END_ENTITY;
        ENTITY wide_thing SUBTYPE OF (base_thing);
          extra : INTEGER;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  def derive(schema, **options)
    Expressir::P28::Xsd.format(schema, **options)
  end

  it "derives byte-identically to the default binding when no directives are set" do
    [values_demo, shaped].each do |schema|
      expect(derive(schema, configuration: described_class.empty))
        .to eq(derive(schema))
    end
  end

  it "overrides the target namespace from the configuration" do
    config = described_class.parse(
      <<~XML,
        <configuration xmlns="urn:iso10303-28:ex" id="c1"
                       targetNamespace="urn:example:configured"/>
      XML
    )
    derived = derive(values_demo, configuration: config)
    doc = Moxml::Context.new.parse(derived)
    expect(doc.root.attribute("targetNamespace").value)
      .to eq("urn:example:configured")
  end

  it "applies the camel-case naming convention" do
    config = described_class.parse(
      <<~XML,
        <configuration xmlns="urn:iso10303-28:ex" id="c1">
          <option naming-convention="camel-case"/>
        </configuration>
      XML
    )
    derived = derive(shaped, configuration: config)
    expect(derived).to include(%(name="baseThing"))
    expect(derived).to include(%(name="baseLabel"))
    expect(derived).not_to include(%(name="Base_thing"))
  end

  it "applies preserve-case without case mapping" do
    config = described_class.parse(
      <<~XML,
        <configuration xmlns="urn:iso10303-28:ex" id="c1">
          <option naming-convention="preserve-case"/>
        </configuration>
      XML
    )
    derived = derive(shaped, configuration: config)
    expect(derived).to include(%(name="base_thing"))
  end

  it "applies explicit entity, type and attribute renames through type references" do
    config = described_class.parse(
      <<~XML,
        <configuration xmlns="urn:iso10303-28:ex" id="c1">
          <type select="colour" name="Hue"/>
          <entity select="box" name="Crate">
            <attribute select="label" name="mark"/>
          </entity>
        </configuration>
      XML
    )
    derived = derive(values_demo, configuration: config)
    expect(derived).to include(%(name="Crate"))
    expect(derived).to include(%(name="Hue"))
    expect(derived).to include(%(name="mark"))
    expect(derived).not_to include(%(name="Box"))
    # the widget's entity reference follows the rename
    expect(derived).to include(%(type="vd:Crate"))
    # the accessor's enumeration type reference follows the rename
    expect(derived).to include(%(type="Hue"))
  end

  it "rejects an unknown naming convention" do
    expect do
      described_class.parse(
        <<~XML,
          <configuration xmlns="urn:iso10303-28:ex" id="c1">
            <option naming-convention="shouting"/>
          </configuration>
        XML
      )
    end.to raise_error(Expressir::UsageError, /naming-convention/)
  end

  it "parses but does not apply directives outside the applied subset (D-04)" do
    untouched = <<~XML
      <configuration xmlns="urn:iso10303-28:ex" id="c1">
        <option inheritance="true" exp-attribute="attribute-tag" sparse="true"/>
        <entity select="box" exp-type="root" tagless="true"/>
        <attribute select="label" keep="true" content="value"/>
      </configuration>
    XML
    config = described_class.parse(untouched)
    expect(derive(values_demo, configuration: config))
      .to eq(derive(values_demo, configuration: described_class.empty))
  end

  it "rejects a document that is not a configuration" do
    expect do
      described_class.parse("<other xmlns='urn:iso10303-28:ex'/>")
    end.to raise_error(Expressir::UsageError, /configuration/)
  end
end
