# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::Parser, :no_cache do
  # The Rust core path (use_core: true) must produce a byte-identical
  # model to the Ruby parse path: every declaration, type, expression,
  # statement — and position-dependent remark attachment, which rides
  # on source_offset carried by the hydrate-only wire mapping.
  def syntax_fixtures
    Dir[File.expand_path("../../syntax/*.exp", __dir__)]
  end

  it "hydrates the same model structure as the Ruby path" do
    skip "expressir core extension not compiled" unless Expressir::Express::Core::NATIVE_AVAILABLE

    failures = syntax_fixtures.filter_map do |file|
      ruby_model = described_class.from_file(file)
      core_model = described_class.from_file(file, use_core: true)
      next unless ruby_model.to_hash != core_model.to_hash

      File.basename(file)
    rescue Expressir::Express::Error::SchemaParseFailure
      # Unparseable on both paths — covered by the failure-parity
      # example below.
      nil
    rescue StandardError => e
      "#{File.basename(file)} raised #{e.class}"
    end
    expect(failures).to be_empty
  end

  it "reports the same parse failures as the Ruby path" do
    skip "expressir core extension not compiled" unless Expressir::Express::Core::NATIVE_AVAILABLE

    syntax_fixtures.each do |file|
      ruby_outcome = begin
        described_class.from_file(file)
        :ok
      rescue Expressir::Express::Error::SchemaParseFailure
        :failure
      end
      core_outcome = begin
        described_class.from_file(file, use_core: true)
        :ok
      rescue Expressir::Express::Error::SchemaParseFailure
        :failure
      end
      expect(core_outcome).to eq(ruby_outcome), file
    end
  end
end
