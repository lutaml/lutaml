# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "expressir"

RSpec.describe Expressir::P21::Diff do
  def population(body)
    Expressir::P21::Parser.parse(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('d.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('demo'));
      ENDSEC;
      DATA;
      #{body}
      ENDSEC;
      END-ISO-10303-21;
    P21
  end

  it "reports added, removed and changed instances" do
    base = population("#1=POINT(1.0);\n#2=POINT(2.0);\n#3=LINE(#1,#2);")
    revised = population("#1=POINT(1.0);\n#2=POINT(9.0);\n#4=LINE(#1,#2);")
    deltas = described_class.diff(base, revised)
    expect(deltas[:added]).to eq(["#4"])
    expect(deltas[:removed]).to eq(["#3"])
    expect(deltas[:changed]).to eq(["#2"])
  end

  it "treats identical populations as empty" do
    body = "#1=POINT(1.0);\n#2=POINT(2.0);"
    expect(described_class.diff(population(body), population(body)))
      .to eq(added: [], removed: [], changed: [])
  end

  it "sees a change inside a complex instance" do
    base = population("#5=(A(1)B('x'));")
    revised = population("#5=(A(2)B('x'));")
    expect(described_class.diff(base, revised)[:changed]).to eq(["#5"])
  end
end
