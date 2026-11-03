# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Spa::OutputStrategy do
  describe "#write" do
    it "raises NotImplementedError" do
      strategy = described_class.new("/tmp/output")
      expect { strategy.write("{}") }.to raise_error(NotImplementedError)
    end
  end
end
