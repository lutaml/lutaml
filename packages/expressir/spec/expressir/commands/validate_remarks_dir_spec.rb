# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Commands::ValidateRemarks do
  it "accepts a directory of schemas" do
    Dir.mktmpdir("remarks-cli") do |dir|
      schema_dir = File.join(dir, "schemas")
      FileUtils.mkdir_p(schema_dir)
      File.write(File.join(schema_dir, "sample.exp"),
                 "SCHEMA sample;\nENTITY a; END_ENTITY;\nEND_SCHEMA;\n")

      expect do
        described_class.new({}).run([schema_dir])
      end.not_to raise_error
    end
  end
end
