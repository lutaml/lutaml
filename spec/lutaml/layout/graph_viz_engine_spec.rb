# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Layout::GraphVizEngine do
  describe "#render" do
    subject(:render) do
      described_class.new(input: input).render(type)
    end
    let(:input) do
      File.read(fixtures_path("generated_dot/AddressClassProfile.dot"))
    end

    context "when png output type" do
      let(:type) { "png" }
      let(:png_header) { "\x89PNG" }

      it "renders input as png binary string" do
        expect(render[0..3]).to(eq(png_header))
      end
    end

    context "when dot output type" do
      let(:type) { "dot" }

      it "renders input as dot string" do
        expect(render).to(match("digraph G {"))
      end
    end
  end
end
