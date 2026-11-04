# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Commands::Xsd do
  it "writes the xsd to the --output path" do
    Dir.mktmpdir("xsd-cli") do |dir|
      exp = File.join(dir, "s.exp")
      File.write(exp, "SCHEMA s;\nENTITY e; x : STRING; END_ENTITY;\nEND_SCHEMA;\n")
      out = File.join(dir, "s.xsd")

      described_class.new({ output: out }).run(exp)

      expect(File.read(out)).to include('<xs:element name="e" type="e"')
    end
  end
end
