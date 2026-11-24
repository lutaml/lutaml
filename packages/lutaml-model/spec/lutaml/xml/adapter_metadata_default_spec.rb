# frozen_string_literal

require "spec_helper"

RSpec.describe "XML adapter metadata default (#908)" do
  it "resolves to leptris when moxml reports no preference" do
    # Hermetic from any adapter previously resolved by other spec files:
    # clear both lutaml's resolver and moxml's memoized selection state
    Lutaml::Model::AdapterResolver.reset!
    Moxml::Config.reset_adapter_selection!

    allow(Moxml::Config).to receive(:runtime_default_adapter).and_return(nil)

    # "No preference" must not be swayed by engines that earlier spec
    # files loaded into the process; hide them for this resolution
    hide_const("Ox")
    hide_const("Oga")

    adapter = Lutaml::Model::Config.adapter_for(:xml)
    expect(adapter.name).to eq("Lutaml::Xml::Adapter::LeptrisAdapter")
  ensure
    Lutaml::Model::AdapterResolver.reset!
    Moxml::Config.reset_adapter_selection!
  end
end
