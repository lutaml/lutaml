# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Express::InterfaceDot do
  def parse_repository(sources)
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path),
                                                       skip_references: true)
    files.each(&:unlink)
    repository
  end

  let(:repository) do
    parse_repository(
      "leaf" => <<~EXP,
        SCHEMA leaf;
        TYPE label = STRING; END_TYPE;
        END_SCHEMA;
      EXP
      "mid" => <<~EXP,
        SCHEMA mid;
        USE FROM leaf (label);
        END_SCHEMA;
      EXP
      "root" => <<~EXP,
        SCHEMA root;
        USE FROM mid;
        REFERENCE FROM leaf (label);
        END_SCHEMA;
      EXP
    )
  end

  def root
    repository.schemas.find { |s| s.id == "root" }
  end

  it "emits a digraph with USE (blue) and REFERENCE (green) edges" do
    text = described_class.new(root, repository).write
    aggregate_failures do
      expect(text).to include("digraph interfaces {")
      expect(text).to include("edge [color=blue]")
      expect(text).to include("edge [color=green]")
      expect(text).to include("root -> mid [arrowhead=normal]")
      expect(text).to include("mid -> leaf [arrowhead=curve]")
      expect(text).to include("root -> leaf [arrowhead=curve]")
    end
  end

  it "honors iface: :use to drop REFERENCE edges" do
    text = described_class.new(root, repository, iface: :use).write
    expect(text).not_to include("color=green")
    expect(text).not_to include("root -> leaf")
    expect(text).to include("root -> mid")
  end

  it "honors depth to bound the walk" do
    text = described_class.new(root, repository, depth: 1).write
    expect(text).to include("root -> mid")
    expect(text).not_to include("mid -> leaf")
  end
end
