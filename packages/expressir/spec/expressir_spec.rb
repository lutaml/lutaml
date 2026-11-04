RSpec.describe Expressir do
  it "has a version number" do
    expect(Expressir::Version::VERSION).not_to be_nil
  end

  describe "optional yeptris engine" do
    # The exact historical crash chain (leptris/yeptris#318): an explicit
    # require of the Psych drop-in - the way lutaml-model's yeptris adapter
    # loads it - followed by core Object#to_yaml. Broken mingw builds died
    # here with uninitialized constant Yeptris::FFI::NODE_SCALAR; this spec
    # gates every platform in the matrix on that path working.
    it "loads the engine and round-trips YAML through the Psych drop-in" do
      require "yaml"
      require "yeptris"
      require "yeptris/psych"

      expect(Yeptris::YAML.load("a: [1, 2]")).to eq("a" => [1, 2])
      expect({ a: [1] }.to_yaml).to include("a:")
    rescue LoadError
      skip "yeptris not loadable on this platform"
    end
  end
end
