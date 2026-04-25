# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/presenters/" \
                 "presenter_factory"
require_relative "../../../../lib/lutaml/uml_repository/presenters/" \
                 "element_presenter"

RSpec.describe Lutaml::UmlRepository::Presenters::PresenterFactory do
  # Create test classes
  class TestElement
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end

  class TestElementChild < TestElement
  end

  class TestPresenter < Lutaml::UmlRepository::Presenters::ElementPresenter
    def to_text
      "Test: #{element.name}"
    end

    def to_table_row
      { type: "Test", name: element.name }
    end

    def to_hash
      { type: "Test", name: element.name }
    end
  end

  let(:test_element) { TestElement.new("TestItem") }
  let(:test_child) { TestElementChild.new("ChildItem") }

  before do
    # Clear any existing registrations before each test
    described_class.instance_variable_set(:@presenters, {})
  end

  describe ".register" do
    it "registers a presenter for an element class" do
      described_class.register(TestElement, TestPresenter)
      expect(described_class.presenters[TestElement]).to eq(TestPresenter)
    end

    it "allows multiple registrations", :aggregate_failures do
      described_class.register(TestElement, TestPresenter)
      described_class.register(TestElementChild, TestPresenter)
      expect(described_class.presenters).to have_key(TestElement)
      expect(described_class.presenters).to have_key(TestElementChild)
    end
  end

  describe ".presenters" do
    it "returns empty hash when no presenters registered" do
      expect(described_class.presenters).to eq({})
    end

    it "returns all registered presenters", :aggregate_failures do
      described_class.register(TestElement, TestPresenter)
      presenters = described_class.presenters
      expect(presenters).to be_a(Hash)
      expect(presenters[TestElement]).to eq(TestPresenter)
    end
  end

  describe ".create" do
    context "with exact class match" do
      before do
        described_class.register(TestElement, TestPresenter)
      end

      it "creates presenter instance", :aggregate_failures do
        presenter = described_class.create(test_element)
        expect(presenter).to be_a(TestPresenter)
        expect(presenter.element).to eq(test_element)
      end

      it "passes repository to presenter" do
        repo = double("Repository")
        presenter = described_class.create(test_element, repo)
        expect(presenter.repository).to eq(repo)
      end
    end

    context "with inheritance chain match" do
      before do
        described_class.register(TestElement, TestPresenter)
      end

      it "finds presenter through inheritance", :aggregate_failures do
        presenter = described_class.create(test_child)
        expect(presenter).to be_a(TestPresenter)
        expect(presenter.element).to eq(test_child)
      end
    end

    context "with no matching presenter" do
      it "raises ArgumentError" do
        expect { described_class.create(test_element) }
          .to raise_error(ArgumentError,
                          /No presenter registered for/)
      end

      it "includes element class in error message" do
        expect { described_class.create(test_element) }
          .to raise_error(ArgumentError, /TestElement/)
      end

      it "lists available presenters in error message" do
        described_class.register(String, TestPresenter)
        expect { described_class.create(test_element) }
          .to raise_error(ArgumentError, /Available: String/)
      end
    end
  end

  describe "integration with presenter methods" do
    before do
      described_class.register(TestElement, TestPresenter)
    end

    it "creates functional presenter", :aggregate_failures do
      presenter = described_class.create(test_element)
      expect(presenter.to_text).to eq("Test: TestItem")
      expect(presenter.to_table_row).to eq({ type: "Test",
                                             name: "TestItem" })
      expect(presenter.to_hash).to eq({ type: "Test", name: "TestItem" })
    end
  end
end
