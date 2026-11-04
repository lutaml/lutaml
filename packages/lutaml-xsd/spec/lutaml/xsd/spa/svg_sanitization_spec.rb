# frozen_string_literal: true

require "spec_helper"
require "timeout"

RSpec.describe "SPA slug and SVG sanitisation" do
  let(:serializer) do
    Lutaml::Xsd::Spa::SchemaSerializer.allocate
  end
  let(:renderer) do
    Lutaml::Xsd::Spa::Svg::ComponentRenderer.allocate
  end

  describe "slugify (both implementations)" do
    {
      "PersonType" => "person-type",
      "XMLSchema" => "xml-schema",
      "HTTPParserV2" => "http-parser-v2",
      "person" => "person",
      "Person_Type@123" => "person-type-123",
      "ABc" => "a-bc",
    }.each do |input, expected|
      it "slugs #{input.inspect} as #{expected.inspect}" do
        expect(serializer.send(:slugify, input)).to eq(expected)
        expect(renderer.send(:slugify, input)).to eq(expected)
      end
    end

    it "finishes quickly on a long run of capitals" do
      [serializer, renderer].each do |obj|
        expect { Timeout.timeout(1) { obj.send(:slugify, "A" * 100_000) } }
          .not_to raise_error
      end
    end
  end

  describe "strip_svg_scripts" do
    def strip(svg) = serializer.send(:strip_svg_scripts, svg)

    it "leaves script-free SVG untouched" do
      svg = '<svg xmlns="http://www.w3.org/2000/svg"><g><text>a &lt; b</text></g></svg>'
      expect(strip(svg)).to eq(svg)
    end

    it "removes plain script elements" do
      expect(strip("<svg><script>x()</script><g/></svg>")).to eq("<svg><g/></svg>")
    end

    it "removes script elements whose end tag has trailing whitespace" do
      expect(strip("<svg><script>x()</script ><g/></svg>")).to eq("<svg><g/></svg>")
    end

    it "does not let removal reassemble a script tag" do
      out = strip("<svg><scr<script></script>ipt>alert(1)</scr<script></script>ipt></svg>")
      expect(out).not_to match(/<\/?script/i)
    end

    it "neutralises an unclosed script opener" do
      expect(strip("<svg><script>alert(1)")).not_to match(/<script/i)
    end
  end
end
