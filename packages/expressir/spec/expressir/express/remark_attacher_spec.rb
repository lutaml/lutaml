require "spec_helper"

RSpec.describe Expressir::Express::RemarkAttacher do
  describe "#innermost_candidate" do
    let(:attacher) { described_class.new("") }
    let(:parent) { Expressir::Model::Statements::Repeat.new }
    let(:child) { Expressir::Model::Statements::If.new }

    # innermost_candidate reads the ownership map off the node index that
    # attach installs, so the helper specs install one directly.
    def with_node_index(nodes)
      index = instance_double(Expressir::Express::NodePositionIndex,
                              nodes: nodes)
      attacher.instance_variable_set(:@node_index, index)
      attacher
    end

    it "prefers the ownership leaf over a smaller-span ancestor" do
      # Node end lines are child-derived approximations: a parent's span can
      # come out SMALLER than its own child's. Span size alone then picks
      # the ancestor. Observed on a production schema, where a comment
      # between END_REPEAT and a nested IF migrated below the enclosing
      # END_IF.
      candidates = [
        { node: parent, line: 10, end_line: 20, owner: nil, collection: nil },
        { node: child, line: 12, end_line: 25, owner: parent,
          collection: :statements },
      ]

      chosen = with_node_index(candidates)
        .send(:innermost_candidate, candidates)

      expect(chosen[:node]).to be(child)
    end

    it "falls back to smallest span among unrelated candidates" do
      sibling = Expressir::Model::Statements::If.new
      candidates = [
        { node: child, line: 12, end_line: 25, owner: nil,
          collection: :statements },
        { node: sibling, line: 14, end_line: 18, owner: nil,
          collection: :statements },
      ]

      chosen = with_node_index(candidates)
        .send(:innermost_candidate, candidates)

      expect(chosen[:node]).to be(sibling)
    end

    it "builds the ownership lookup once for an immutable node index" do
      nodes = [
        { node: parent, line: 10, end_line: 20, owner: nil, collection: nil },
        { node: child, line: 12, end_line: 25, owner: parent,
          collection: :statements },
      ]
      # Asserts the node index is consulted once, rather than pinning the
      # collection method the map happens to be built with.
      index = instance_double(Expressir::Express::NodePositionIndex)
      expect(index).to receive(:nodes).once.and_return(nodes)
      attacher.instance_variable_set(:@node_index, index)

      2.times { attacher.send(:innermost_candidate, nodes) }
    end
  end

  describe "#attach" do
    let(:attacher) { described_class.new("SCHEMA s; END_SCHEMA;") }

    it "drops the memoized ownership map when attachment raises" do
      # Build the map first, so the assertion below is about the ensure
      # block dropping a populated map rather than one that was never set.
      allow(attacher).to receive(:attach_tagged_remarks) do
        attacher.send(:owner_map)
        raise "boom"
      end

      expect { attacher.attach(Expressir::Model::Repository.new) }
        .to raise_error("boom")
      expect(attacher.instance_variable_get(:@owner_map)).to be_nil
      expect(attacher.instance_variable_get(:@node_index)).to be_nil
    end
  end

  describe "#where_clause_line_index" do
    let(:source) do
      <<~EXP
        SCHEMA demo;
        RULE size_check FOR (item) IS
          WHERE valid_count : SIZEOF(item) > 0;
        END_RULE;
        RULE other_check FOR (thing) IS
          WHERE VALID_COUNT : SIZEOF(thing) > 1;
        END_RULE;
        END_SCHEMA;
      EXP
    end
    let(:attacher) { described_class.new(source) }

    it "maps WHERE labels to their line numbers, case-insensitively" do
      index = attacher.send(:where_clause_line_index)
      expect(index.keys).to contain_exactly("valid_count", "VALID_COUNT")
    end

    it "collects every occurrence of a repeated label in line order" do
      doubled = source + source
      index = described_class.new(doubled).send(:where_clause_line_index)
      lines = index["valid_count"].sort
      expect(lines.length).to eq(2)
      expect(lines).to eq(lines.sort)
    end

    it "does not treat ordinary lines as WHERE clauses" do
      index = attacher.send(:where_clause_line_index)
      expect(index).not_to have_key("item")
    end
  end
end
