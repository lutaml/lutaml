# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "lazy parsanol loading" do
  def loaded_in_fresh_ruby(requires, probe)
    lib = File.expand_path("../../../lib", __dir__)
    code = "#{requires.map { |r| "require #{r.inspect}" }.join('; ')}; " \
           "print(#{probe})"
    out, status = Open3.capture2e(RbConfig.ruby, "-I", lib, "-e", code)
    raise "subprocess failed: #{out}" unless status.success?

    out
  end

  it "does not load parsanol when only the runtime is required" do
    expect(loaded_in_fresh_ruby(%w[lutaml], "defined?(Parsanol).inspect"))
      .to eq("nil")
  end

  it "loads parsanol on first parse" do
    out = loaded_in_fresh_ruby(
      %w[lutaml],
      "(Lutaml::Lml.parse('models M { class A {} }'); defined?(Parsanol).inspect)",
    )

    expect(out).to eq('"constant"')
  end
end
