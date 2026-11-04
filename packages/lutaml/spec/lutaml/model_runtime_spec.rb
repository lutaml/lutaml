# frozen_string_literal: true

require "open3"
require "rbconfig"

# lutaml carries the lutaml-model runtime (#233): a plain `require "lutaml"`
# in a fresh process must make the model API available.
RSpec.describe "lutaml model runtime" do
  def run_ruby(code)
    lib = File.expand_path("../../lib", __dir__)
    Open3.capture3(RbConfig.ruby, "-I", lib, "-e", code)
  end

  it "defines the model runtime after require 'lutaml'" do
    out, err, status = run_ruby(<<~RUBY)
      require "lutaml"
      class Probe < Lutaml::Model::Serializable
        attribute :name, :string
        key_value { map "name", to: :name }
      end
      puts Probe.from_yaml("name: x").name
    RUBY

    expect([out.strip, status.success?]).to eq(["x", true]), err
  end

  it "ships the runtime under lib/lutaml/model" do
    expect(File).to exist(File.expand_path("../../lib/lutaml/model.rb", __dir__))
  end
end
