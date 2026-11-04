# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/content_model_matcher"

RSpec.describe Lutaml::Xsd::Validation::ContentModelMatcher do
  # Occurrence-configurable particle stand-in: only min/max matter to
  # the automaton; object identity distinguishes particles in the
  # element predicate.
  def particle(min = nil, max = nil)
    Struct.new(:min_occurs, :max_occurs).new(min, max)
  end

  def parse_schema(xsd)
    Lutaml::Xml::Schema::Xsd.parse(xsd)
  end

  def build(list, members: nil, group_expansion: [])
    described_class.new(
      list,
      element_match: ->(child, particle) { child.equal?(particle) },
      wildcard_match: ->(child, _particle) { child == :wild },
      container_particles: ->(container) do
        members || Array(container.element)
      end,
      group_particles: ->(_group) { group_expansion },
    )
  end

  describe "sequence" do
    it "accepts the ordered sequence" do
      a = particle
      b = particle

      expect(build([a, b]).match([a, b]).matched).to be(true)
    end

    it "rejects transposed children" do
      a = particle
      b = particle

      expect(build([a, b]).match([b, a]).matched).to be(false)
    end

    it "rejects a repeated child beyond max" do
      a = particle
      b = particle

      expect(build([a, b]).match([a, a]).matched).to be(false)
    end

    it "reports the failing child index" do
      a = particle
      b = particle
      result = build([a, b]).match([b, a])

      expect(result.fail_reason).to eq(:unexpected_child)
      expect(result.fail_index).to eq(0)
    end

    it "reports incomplete when required content is missing" do
      a = particle
      b = particle
      result = build([a, b]).match([a])

      expect(result.matched).to be(false)
      expect(result.fail_reason).to eq(:incomplete)
    end
  end

  describe "occurrence ranges" do
    it "skips and keeps an optional particle" do
      opt = particle("0", "1")
      req = particle

      expect(build([opt, req]).match([req]).matched).to be(true)
      expect(build([opt, req]).match([opt, req]).matched).to be(true)
    end

    it "repeats an unbounded particle before a required tail" do
      star = particle("0", "unbounded")
      req = particle

      expect(build([star, req]).match([req]).matched).to be(true)
      expect(build([star, req]).match([star, star, req]).matched).to be(true)
      expect(build([star, req]).match([star]).matched).to be(false)
    end

    it "requires at least one occurrence of a one-or-more particle" do
      plus = particle("1", "unbounded")

      expect(build([plus]).match([plus, plus]).matched).to be(true)
      expect(build([plus]).match([]).matched).to be(false)
    end

    it "honours bounded ranges" do
      bounded = particle("2", "4")

      expect(build([bounded]).match([bounded, bounded]).matched).to be(true)
      expect(build([bounded]).match([bounded]).matched).to be(false)
      expect(build(
        [bounded],
      ).match(Array.new(5, bounded)).matched).to be(false)
    end
  end

  describe "choice" do
    let(:xsd) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:choice>
                <xs:element name="a"/>
                <xs:element name="b"/>
                <xs:element name="c"/>
              </xs:choice>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    let(:choice) { parse_schema(xsd).element.first.complex_type.choice }
    let(:ea) { Array(choice.element)[0] }
    let(:eb) { Array(choice.element)[1] }
    let(:ec) { Array(choice.element)[2] }

    it "accepts exactly one branch" do
      expect(build([choice]).match([eb]).matched).to be(true)
    end

    it "rejects two branches in one occurrence" do
      result = build([choice]).match([ea, eb])

      expect(result.matched).to be(false)
      expect(result.fail_index).to eq(1)
    end

    it "combines with sequence context" do
      expect(build([ea, choice, ec]).match([ea, eb, ec]).matched).to be(true)
      expect(build([ea, choice, ec]).match([ec, ea]).matched).to be(false)
    end
  end

  describe "wildcards" do
    let(:xsd) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="a"/>
                <xs:any processContents="lax"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    let(:particles) do
      ct = parse_schema(xsd).element.first.complex_type
      seq = ct.sequence
      Array(seq.element) + Array(seq.any)
    end

    it "accepts a wildcard-admitted child in place" do
      expect(build(particles).match(
        [particles[0], :wild],
      ).matched).to be(true)
    end

    it "does not let a wildcard admit a required declared child" do
      expect(build(particles).match(
        [particles[0], :other],
      ).matched).to be(false)
    end
  end

  describe "xs:all" do
    let(:xsd) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="doc">
            <xs:complexType>
              <xs:all>
                <xs:element name="a"/>
                <xs:element name="b" minOccurs="0"/>
              </xs:all>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    let(:all_particle) do
      parse_schema(xsd).element.first.complex_type.all
    end
    let(:members) { Array(all_particle.element) }

    def all_matcher
      build([all_particle], members: members)
    end

    it "accepts members in any order" do
      expect(all_matcher.match(members).matched).to be(true)
      expect(all_matcher.match(members.reverse).matched).to be(true)
    end

    it "rejects a duplicated member" do
      expect(all_matcher.match([members[0], members[0],
                                members[1]]).matched).to be(false)
    end

    it "accepts when only optional members are missing" do
      expect(all_matcher.match([members[0]]).matched).to be(true)
      expect(all_matcher.match([]).matched).to be(false)
    end
  end

  describe "group refs" do
    let(:xsd) do
      <<~XSD
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:group name="pair">
            <xs:sequence>
              <xs:element name="x"/>
              <xs:element name="y"/>
            </xs:sequence>
          </xs:group>
          <xs:element name="doc">
            <xs:complexType>
              <xs:group ref="pair" minOccurs="0" maxOccurs="unbounded"/>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XSD
    end

    let(:schema) { parse_schema(xsd) }
    let(:group_ref) { schema.element.first.complex_type.group }
    let(:expanded) { [Array(schema.group.first.sequence).first] }
    let(:inner) { Array(expanded.first.element) }

    it "expands a group ref and honours the ref's occurrence" do
      matcher = build([group_ref], group_expansion: expanded)

      expect(matcher.match(inner).matched).to be(true)
      expect(matcher.match(inner + inner).matched).to be(true)
      expect(matcher.match([inner[0]]).matched).to be(false)
    end

    it "treats an unresolvable group ref as empty" do
      matcher = build([group_ref], group_expansion: [])

      expect(matcher.match([]).matched).to be(true)
      expect(matcher.match([particle]).matched).to be(false)
    end
  end
end
