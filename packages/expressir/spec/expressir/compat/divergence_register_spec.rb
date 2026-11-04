# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "yaml"

# The subject is a documentation register, not a Ruby class.
# rubocop:disable RSpec/DescribeClass

# TODO.compat/02: the divergence register is the compatibility
# contract — every registered D-NN entry must cite an existing spec
# that pins it, so entries cannot drift from the suite.
RSpec.describe "compat divergence register" do
  let(:register_path) do
    Expressir.root_path.join("docs/_guides/compat/interchange.adoc")
  end

  def register_ids
    register_path.read.scan(/^\| (D-\d+)\n/).flatten.uniq
  end

  def cited_specs(entry_text)
    entry_text.scan(/`([^`]+_spec\.rb)`/).flatten.uniq
  end

  it "exists with at least one registered divergence" do
    expect(register_ids).not_to be_empty
  end

  it "cites only spec files that exist" do
    spec_dir = Expressir.root_path.join("spec")
    missing = register_path.read.scan(/`(spec\/expressir[^`]+_spec\.rb)`/)
      .flatten.uniq.reject { |rel| spec_dir.parent.join(rel).exist? }
    expect(missing).to be_empty
  end

  it "has contiguous D-NN ids" do
    numbers = register_ids.map { |id| Integer(id.delete_prefix("D-")) }
    expect(numbers).to eq((1..numbers.max).to_a)
  end
end
# rubocop:enable RSpec/DescribeClass
