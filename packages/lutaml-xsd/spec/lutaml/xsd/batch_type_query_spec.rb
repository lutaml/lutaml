# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/batch_type_query"
require "tempfile"

RSpec.describe Lutaml::Xsd::BatchTypeQuery do
  let(:repository) { instance_double(Lutaml::Xsd::SchemaRepository) }
  let(:batch_query) { described_class.new(repository) }

  describe "#initialize" do
    it "initializes with a repository" do
      expect(batch_query.repository).to eq(repository)
    end
  end

  describe "#execute" do
    let(:qname1) { "ns:Type1" }
    let(:qname2) { "ns:Type2" }
    let(:qname3) { "ns:Type3" }

    let(:result1) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: true,
        qname: qname1,
        namespace: "http://example.com/ns",
        definition: Lutaml::Xml::Schema::Xsd::ComplexType.new,
      )
    end

    let(:result2) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: true,
        qname: qname2,
        namespace: "http://example.com/ns",
        definition: instance_double(Lutaml::Xml::Schema::Xsd::SimpleType,
                                    class: Lutaml::Xml::Schema::Xsd::SimpleType),
      )
    end

    let(:result3) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: false,
        qname: qname3,
        namespace: nil,
        definition: nil,
      )
    end

    before do
      allow(repository).to receive(:find_type).with(qname1).and_return(result1)
      allow(repository).to receive(:find_type).with(qname2).and_return(result2)
      allow(repository).to receive(:find_type).with(qname3).and_return(result3)
    end

    it "executes batch query for multiple qualified names" do
      results = batch_query.execute([qname1, qname2, qname3])

      expect(results.size).to eq(3)
      expect(results).to all(be_a(Lutaml::Xsd::BatchQueryResult))
    end

    it "returns resolved results for found types" do
      results = batch_query.execute([qname1, qname2])

      expect(results[0].resolved).to be true
      expect(results[0].query).to eq(qname1)
      expect(results[0].result).to eq(result1)

      expect(results[1].resolved).to be true
      expect(results[1].query).to eq(qname2)
      expect(results[1].result).to eq(result2)
    end

    it "returns unresolved results for not found types" do
      results = batch_query.execute([qname3])

      expect(results[0].resolved).to be false
      expect(results[0].query).to eq(qname3)
      expect(results[0].result).to eq(result3)
    end

    it "strips whitespace from qualified names" do
      allow(repository).to receive(:find_type).with(qname1).and_return(result1)

      results = batch_query.execute([" #{qname1} ", "  #{qname1}"])

      expect(results.size).to eq(2)
      expect(results[0].query).to eq(" #{qname1} ")
      expect(results[1].query).to eq("  #{qname1}")
    end
  end

  describe "#execute_from_file" do
    let(:qname1) { "ns:Type1" }
    let(:qname2) { "ns:Type2" }

    let(:result1) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: true,
        qname: qname1,
        namespace: "http://example.com/ns",
        definition: Lutaml::Xml::Schema::Xsd::ComplexType.new,
      )
    end

    let(:result2) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: true,
        qname: qname2,
        namespace: "http://example.com/ns",
        definition: instance_double(Lutaml::Xml::Schema::Xsd::SimpleType,
                                    class: Lutaml::Xml::Schema::Xsd::SimpleType),
      )
    end

    it "executes batch query from file" do
      file = Tempfile.new("batch_types")
      file.write("#{qname1}\n#{qname2}\n")
      file.close

      allow(repository).to receive(:find_type).with(qname1).and_return(result1)
      allow(repository).to receive(:find_type).with(qname2).and_return(result2)

      results = batch_query.execute_from_file(file.path)

      expect(results.size).to eq(2)
      expect(results[0].query).to eq(qname1)
      expect(results[1].query).to eq(qname2)

      file.unlink
    end

    it "ignores empty lines in file" do
      file = Tempfile.new("batch_types")
      file.write("#{qname1}\n\n#{qname2}\n\n")
      file.close

      allow(repository).to receive(:find_type).with(qname1).and_return(result1)
      allow(repository).to receive(:find_type).with(qname2).and_return(result2)

      results = batch_query.execute_from_file(file.path)

      expect(results.size).to eq(2)

      file.unlink
    end
  end

  describe "#execute_from_stdin" do
    let(:qname1) { "ns:Type1" }
    let(:qname2) { "ns:Type2" }

    let(:result1) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: true,
        qname: qname1,
        namespace: "http://example.com/ns",
        definition: Lutaml::Xml::Schema::Xsd::ComplexType.new,
      )
    end

    let(:result2) do
      instance_double(
        Lutaml::Xsd::TypeResolutionResult,
        resolved?: true,
        qname: qname2,
        namespace: "http://example.com/ns",
        definition: instance_double(Lutaml::Xml::Schema::Xsd::SimpleType,
                                    class: Lutaml::Xml::Schema::Xsd::SimpleType),
      )
    end

    it "executes batch query from stdin" do
      allow($stdin).to receive(:readlines).and_return(["#{qname1}\n",
                                                       "#{qname2}\n"])
      allow(repository).to receive(:find_type).with(qname1).and_return(result1)
      allow(repository).to receive(:find_type).with(qname2).and_return(result2)

      results = batch_query.execute_from_stdin

      expect(results.size).to eq(2)
      expect(results[0].query).to eq(qname1)
      expect(results[1].query).to eq(qname2)
    end

    it "ignores empty lines from stdin" do
      allow($stdin).to receive(:readlines).and_return(["#{qname1}\n", "\n",
                                                       "#{qname2}\n", "\n"])
      allow(repository).to receive(:find_type).with(qname1).and_return(result1)
      allow(repository).to receive(:find_type).with(qname2).and_return(result2)

      results = batch_query.execute_from_stdin

      expect(results.size).to eq(2)
    end
  end
end

RSpec.describe Lutaml::Xsd::BatchQueryResult do
  let(:query) { "ns:Type1" }
  let(:resolved) { true }
  let(:definition) do
    Lutaml::Xml::Schema::Xsd::ComplexType.new
  end
  let(:result) do
    instance_double(
      Lutaml::Xsd::TypeResolutionResult,
      qname: query,
      namespace: "http://example.com/ns",
      definition: definition,
    )
  end

  let(:batch_result) do
    described_class.new(query: query, resolved: resolved, result: result)
  end

  describe "#initialize" do
    it "initializes with query, resolved status, and result" do
      expect(batch_result.query).to eq(query)
      expect(batch_result.resolved).to be true
      expect(batch_result.result).to eq(result)
    end
  end

  describe "#to_h" do
    context "when resolved" do
      it "returns hash with all information" do
        hash = batch_result.to_h

        expect(hash[:query]).to eq(query)
        expect(hash[:resolved]).to be true
        expect(hash[:qualified_name]).to eq(query)
        expect(hash[:namespace]).to eq("http://example.com/ns")
        expect(hash[:type_class]).to eq("Lutaml::Xml::Schema::Xsd::ComplexType")
      end
    end

    context "when not resolved" do
      let(:resolved) { false }
      let(:result) do
        instance_double(
          Lutaml::Xsd::TypeResolutionResult,
          qname: query,
          namespace: nil,
          definition: nil,
        )
      end

      it "returns hash with nil type_class" do
        hash = batch_result.to_h

        expect(hash[:query]).to eq(query)
        expect(hash[:resolved]).to be false
        expect(hash[:qualified_name]).to eq(query)
        expect(hash[:namespace]).to be_nil
        expect(hash[:type_class]).to be_nil
      end
    end
  end
end
