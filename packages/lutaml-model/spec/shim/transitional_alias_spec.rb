# frozen_string_literal: true

require "open3"
require "rbconfig"

# lutaml-model is a thin alias of lutaml (#233): the old requires keep
# working and `require "lutaml-model"` prints one deprecation notice.
RSpec.describe "lutaml-model transitional alias" do
  def run_ruby(code, env: {})
    shim_lib = File.expand_path("../../lib", __dir__)
    Open3.capture3(env, RbConfig.ruby, "-I", shim_lib, "-I", LUTAML_LIB, "-e", code)
  end

  let(:probe) do
    <<~RUBY
      class Probe < Lutaml::Model::Serializable
        attribute :name, :string
        key_value { map "name", to: :name }
      end
      puts Probe.from_yaml("name: x").name
    RUBY
  end

  it "loads the runtime through require 'lutaml-model' with one notice" do
    out, err, status = run_ruby(%(require "lutaml-model"; require "lutaml-model"; #{probe}))

    expect([out.strip, status.success?]).to eq(["x", true]), err
    expect(err.scan("[DEPRECATION] the `lutaml-model` gem").size).to eq(1)
  end

  it "keeps require 'lutaml/model' working without a notice" do
    out, err, status = run_ruby(%(require "lutaml/model"; #{probe}))

    expect([out.strip, status.success?]).to eq(["x", true]), err
    expect(err).not_to include("DEPRECATION")
  end

  it "silences the notice with LUTAML_MODEL_SILENCE_DEPRECATION" do
    _out, err, status = run_ruby(%(require "lutaml-model"),
                                 env: { "LUTAML_MODEL_SILENCE_DEPRECATION" => "1" })

    expect(status.success?).to be(true), err
    expect(err).not_to include("DEPRECATION")
  end

  it "declares lutaml as its only runtime dependency" do
    spec = Gem::Specification.load(File.expand_path("../../lutaml-model.gemspec", __dir__))

    expect(spec.runtime_dependencies.map(&:name)).to eq(["lutaml"])
  end
end
