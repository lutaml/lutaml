require "spec_helper"

RSpec.describe Expressir::Express::Parser do
  it "raises a specific error when use_streaming is requested" do
    expect do
      described_class.from_exp("SCHEMA t; END_SCHEMA;", skip_references: true,
                                                        use_streaming: true)
    end.to raise_error(Expressir::Express::Error::StreamingUnsupportedError)
  end

  it "parses normally when use_streaming is not set" do
    exp_file = described_class.from_exp(
      "SCHEMA t; END_SCHEMA;", skip_references: true
    )
    expect(exp_file.schemas.map(&:id)).to eq(["t"])
  end
end
