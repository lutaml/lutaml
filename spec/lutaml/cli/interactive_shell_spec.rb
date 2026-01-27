# frozen_string_literal: true

require "spec_helper"
require "stringio"
require_relative "../../../lib/lutaml/cli/interactive_shell"
require_relative "../../../lib/lutaml/uml_repository/repository"

RSpec.describe Lutaml::Cli::InteractiveShell do
  let(:mock_repo) do
    double(
      "UmlRepository",
      statistics: {
        total_packages: 5,
        total_classes: 20,
        total_data_types: 3,
        total_enums: 2,
        total_diagrams: 1,
        total_attributes: 50,
        total_associations: 10,
        max_package_depth: 2,
        avg_package_depth: 1.5,
        avg_class_complexity: 3.0,
      },
    )
  end

  let(:config) { { color: false, icons: false } }

  describe "#initialize" do
    it "initializes with a repository object" do
      shell = described_class.new(mock_repo, config: config)

      expect(shell.repository).to eq(mock_repo)
      expect(shell.current_path).to eq("ModelRoot")
      expect(shell.bookmarks).to be_empty
    end

    it "sets up default configuration" do
      shell = described_class.new(mock_repo)

      expect(shell.config[:color]).to be true
      expect(shell.config[:icons]).to be true
    end
  end

  describe "command execution" do
    let(:shell) { described_class.new(mock_repo, config: config) }

    describe "#cmd_pwd" do
      it "prints current working directory" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_pwd, [])

        $stdout = original_stdout
        expect(output.string).to include("ModelRoot")
      end
    end

    describe "#cmd_cd" do
      before do
        allow(mock_repo).to receive(:find_package).with("test::package")
          .and_return(double("Package", name: "package"))
      end

      it "changes to specified package" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_cd, ["test::package"])

        $stdout = original_stdout
        expect(output.string).to include("Changed to")
        expect(shell.current_path).to eq("test::package")
      end

      it "shows error for non-existent package" do
        allow(mock_repo).to receive(:find_package).with("nonexistent")
          .and_return(nil)

        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_cd, ["nonexistent"])

        $stdout = original_stdout
        expect(output.string).to include("not found")
      end

      it "shows usage when no path provided" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_cd, [])

        $stdout = original_stdout
        expect(output.string).to include("Usage")
      end
    end

    describe "#cmd_up" do
      before do
        shell.instance_variable_set(:@current_path, "ModelRoot::Package::SubPackage")
      end

      it "goes up one level" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_up, [])

        $stdout = original_stdout
        expect(output.string).to include("Changed to")
        expect(shell.current_path).to eq("ModelRoot::Package")
      end

      it "stays at root when already there" do
        shell.instance_variable_set(:@current_path, "ModelRoot")

        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_up, [])

        $stdout = original_stdout
        expect(output.string).to include("Already at root")
        expect(shell.current_path).to eq("ModelRoot")
      end
    end

    describe "#cmd_root" do
      before do
        shell.instance_variable_set(:@current_path, "ModelRoot::Package")
      end

      it "navigates to root" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_root, [])

        $stdout = original_stdout
        expect(output.string).to include("Changed to")
        expect(shell.current_path).to eq("ModelRoot")
      end
    end

    describe "#cmd_back" do
      before do
        shell.instance_variable_set(:@path_history, ["ModelRoot", "ModelRoot::Package"])
        shell.instance_variable_set(:@current_path, "ModelRoot::Package")
      end

      it "goes back to previous location" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_back, [])

        $stdout = original_stdout
        expect(output.string).to include("Changed to")
        expect(shell.current_path).to eq("ModelRoot")
      end
    end

    describe "#cmd_ls" do
      before do
        allow(mock_repo).to receive(:list_packages)
          .and_return([
            double("Package", name: "Package1"),
            double("Package", name: "Package2"),
          ])
      end

      it "lists packages in current path" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_ls, [])

        $stdout = original_stdout
        expect(output.string).to include("Package1")
        expect(output.string).to include("Package2")
        expect(output.string).to include("Total: 2")
      end

      it "shows warning when no packages found" do
        allow(mock_repo).to receive(:list_packages).and_return([])

        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_ls, [])

        $stdout = original_stdout
        expect(output.string).to include("No packages found")
      end
    end

    describe "#cmd_find" do
      before do
        allow(mock_repo).to receive(:search)
          .and_return(class: ["TestClass", "AnotherClass"])
      end

      it "finds classes and stores results" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_find, ["Test"])

        $stdout = original_stdout
        expect(output.string).to include("Found 2 class")
        expect(output.string).to include("TestClass")
        expect(shell.last_results).to eq(["TestClass", "AnotherClass"])
      end

      it "shows warning when no results found" do
        allow(mock_repo).to receive(:search).and_return(class: [])

        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_find, ["NonExistent"])

        $stdout = original_stdout
        expect(output.string).to include("No classes found")
      end

      it "requires a search term" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_find, [])

        $stdout = original_stdout
        expect(output.string).to include("Usage")
      end
    end

    describe "bookmark management" do
      describe "#bookmark_add" do
        it "adds bookmark for current path" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_add, "my_bookmark")

          $stdout = original_stdout
          expect(output.string).to include("added")
          expect(shell.bookmarks["my_bookmark"]).to eq("ModelRoot")
        end

        it "requires bookmark name" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_add, nil)

          $stdout = original_stdout
          expect(output.string).to include("Usage")
        end
      end

      describe "#bookmark_list" do
        it "lists all bookmarks" do
          shell.instance_variable_set(:@bookmarks,
                                      { "bm1" => "Path1", "bm2" => "Path2" })

          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_list)

          $stdout = original_stdout
          expect(output.string).to include("bm1")
          expect(output.string).to include("Path1")
          expect(output.string).to include("bm2")
          expect(output.string).to include("Path2")
        end

        it "shows message when no bookmarks" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_list)

          $stdout = original_stdout
          expect(output.string).to include("No bookmarks")
        end
      end

      describe "#bookmark_go" do
        before do
          shell.instance_variable_set(:@bookmarks,
                                      { "test" => "ModelRoot::Package" })
          allow(mock_repo).to receive(:find_package).with("ModelRoot::Package")
            .and_return(double("Package", name: "Package"))
        end

        it "jumps to bookmarked location" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_go, "test")

          $stdout = original_stdout
          expect(output.string).to include("Changed to")
          expect(shell.current_path).to eq("ModelRoot::Package")
        end

        it "shows error for non-existent bookmark" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_go, "nonexistent")

          $stdout = original_stdout
          expect(output.string).to include("not found")
        end
      end

      describe "#bookmark_remove" do
        before do
          shell.instance_variable_set(:@bookmarks, { "test" => "Path" })
        end

        it "removes bookmark" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_remove, "test")

          $stdout = original_stdout
          expect(output.string).to include("removed")
          expect(shell.bookmarks).not_to have_key("test")
        end

        it "shows error for non-existent bookmark" do
          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          shell.send(:bookmark_remove, "nonexistent")

          $stdout = original_stdout
          expect(output.string).to include("not found")
        end
      end
    end

    describe "#cmd_results" do
      it "shows last results" do
        shell.instance_variable_set(:@last_results, ["Class1", "Class2"])

        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_results, [])

        $stdout = original_stdout
        expect(output.string).to include("Class1")
        expect(output.string).to include("Class2")
      end

      it "shows warning when no results" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_results, [])

        $stdout = original_stdout
        expect(output.string).to include("No previous results")
      end
    end

    describe "#cmd_stats" do
      it "displays repository statistics" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_stats, [])

        $stdout = original_stdout
        expect(output.string).to include("5")
        expect(output.string).to include("20")
      end
    end

    describe "#cmd_config" do
      it "displays current configuration" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_config, [])

        $stdout = original_stdout
        expect(output.string).to include("Configuration")
        expect(output.string).to include("color")
        expect(output.string).to include("icons")
      end
    end

    describe "#cmd_clear" do
      it "sends clear screen sequence" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_clear, [])

        $stdout = original_stdout
        expect(output.string).to include("\e[2J\e[H")
      end
    end

    describe "#cmd_help" do
      it "displays general help" do
        output = StringIO.new
        original_stdout = $stdout
        $stdout = output

        shell.send(:cmd_help, [])

        $stdout = original_stdout
        expect(output.string).to include("Available Commands")
        expect(output.string).to include("Navigation")
        expect(output.string).to include("Query")
      end
    end
  end

  describe "path resolution" do
    let(:shell) { described_class.new(mock_repo, config: config) }

    it "resolves absolute paths" do
      result = shell.send(:resolve_path, "ModelRoot::Package")
      expect(result).to eq("ModelRoot::Package")
    end

    it "resolves current directory" do
      shell.instance_variable_set(:@current_path, "ModelRoot::Package")
      result = shell.send(:resolve_path, ".")
      expect(result).to eq("ModelRoot::Package")
    end

    it "resolves root" do
      result = shell.send(:resolve_path, "/")
      expect(result).to eq("ModelRoot")
    end

    it "resolves relative paths" do
      shell.instance_variable_set(:@current_path, "ModelRoot::Package")
      result = shell.send(:resolve_path, "SubPackage")
      expect(result).to eq("ModelRoot::Package::SubPackage")
    end
  end
end
