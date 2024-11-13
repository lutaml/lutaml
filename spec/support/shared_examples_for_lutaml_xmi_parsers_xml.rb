RSpec.shared_examples "should output correct klass liquid drop" do |id, name|
  it "outputs Lutaml::XMI::KlassDrop" do
    expect(output).to be_instance_of(Lutaml::XMI::KlassDrop)
  end

  it "correctly parses model name" do
    expect(output.name).to eq(name)
  end

  it "correctly parses xmi_id" do
    expect(output.xmi_id).to eq(id)
  end

  it "correctly outputs generalization" do
    expect(output.generalization).to(
      be_instance_of(Lutaml::XMI::GeneralizationDrop),
    )
  end

  it "correctly parses generalization id" do
    expect(output.generalization.id).to eq(id)
  end
end
