# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "lutaml/cli/interactive_shell"
require "lutaml/uml_repository/repository"

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
      }
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
        expect {
          shell.send(:cmd_pwd, [])
        }.to output(/ModelRoot/).to_stdout
      end
    end

    describe "#cmd_cd" do
      before do
        allow(mock_repo).to receive(:find_package).with("test::package")
          .and_return(double("Package", name: "package"))
      end

      it "changes to specified package" do
        expect {
          shell.send(:cmd_cd, ["test::package"])
        }.to output(/Changed to/).to_stdout

        expect(shell.current_path).to eq("test::package")
      end

      it "shows error for non-existent package" do
        allow(mock_repo).to receive(:find_package).with("nonexistent")
          .and_return(nil)

        expect {
          shell.send(:cmd_cd, ["nonexistent"])
        }.to output(/not found/).to_stdout
      end

      it "shows usage when no path provided" do
        expect {
          shell.send(:cmd_cd, [])
        }.to output(/Usage/).to_stdout
      end
    end

    describe "#cmd_up" do
      before do
        shell.instance_variable_set(:@current_path, "ModelRoot::Package::SubPackage")
      end

      it "goes up one level" do
        expect {
          shell.send(:cmd_up, [])
        }.to output(/Changed to/).to_stdout

        expect(shell.current_path).to eq("ModelRoot::Package")
      end

      it "stays at root when already there" do
        shell.instance_variable_set(:@current_path, "ModelRoot")

        expect {
          shell.send(:cmd_up, [])
        }.to output(/Already at root/).to_stdout

        expect(shell.current_path).to eq("ModelRoot")
      end
    end

    describe "#cmd_root" do
      before do
        shell.instance_variable_set(:@current_path, "ModelRoot::Package")
      end

      it "navigates to root" do
        expect {
          shell.send(:cmd_root, [])
        }.to output(/Changed to/).to_stdout

        expect(shell.current_path).to eq("ModelRoot")
      end
    end

    describe "#cmd_back" do
      before do
        shell.instance_variable_set(:@path_history, ["ModelRoot", "ModelRoot::Package"])
        shell.instance_variable_set(:@current_path, "ModelRoot::Package")
      end

      it "goes back to previous location" do
        expect {
          shell.send(:cmd_back, [])
        }.to output(/Changed to/).to_stdout

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
        expect {
          shell.send(:cmd_ls, [])
        }.to output(/Package1/).to_stdout
         .and output(/Package2/).to_stdout
         .and output(/Total: 2/).to_stdout
      end

      it "shows warning when no packages found" do
        allow(mock_repo).to receive(:list_packages).and_return([])

        expect {
          shell.send(:cmd_ls, [])
        }.to output(/No packages found/).to_stdout
      end
    end

    describe "#cmd_find" do
      before do
        allow(mock_repo).to receive(:search)
          .and_return(class: ["TestClass", "AnotherClass"])
      end

      it "finds classes and stores results" do
        expect {
          shell.send(:cmd_find, ["Test"])
        }.to output(/Found 2 class/).to_stdout
         .and output(/TestClass/).to_stdout

        expect(shell.last_results).to eq(["TestClass", "AnotherClass"])
      end

      it "shows warning when no results found" do
        allow(mock_repo).to receive(:search).and_return(class: [])

        expect {
          shell.send(:cmd_find, ["NonExistent"])
        }.to output(/No classes found/).to_stdout
      end

      it "requires a search term" do
        expect {
          shell.send(:cmd_find, [])
        }.to output(/Usage/).to_stdout
      end
    end

    describe "bookmark management" do
      describe "#bookmark_add" do
        it "adds bookmark for current path" do
          expect {
            shell.send(:bookmark_add, "my_bookmark")
          }.to output(/added/).to_stdout

          expect(shell.bookmarks["my_bookmark"]).to eq("ModelRoot")
        end

        it "requires bookmark name" do
          expect {
            shell.send(:bookmark_add, nil)
          }.to output(/Usage/).to_stdout
        end
      end

      describe "#bookmark_list" do
        it "lists all bookmarks" do
          shell.instance_variable_set(:@bookmarks, { "bm1" => "Path1", "bm2" => "Path2" })

          expect {
            shell.send(:bookmark_list)
          }.to output(/bm1/).to_stdout
           .and output(/Path1/).to_stdout
           .and output(/bm2/).to_stdout
           .and output(/Path2/).to_stdout
        end

        it "shows message when no bookmarks" do
          expect {
            shell.send(:bookmark_list)
          }.to output(/No bookmarks/).to_stdout
        end
      end

      describe "#bookmark_go" do
        before do
          shell.instance_variable_set(:@bookmarks, { "test" => "ModelRoot::Package" })
          allow(mock_repo).to receive(:find_package).with("ModelRoot::Package")
            .and_return(double("Package", name: "Package"))
        end

        it "jumps to bookmarked location" do
          expect {
            shell.send(:bookmark_go, "test")
          }.to output(/Changed to/).to_stdout

          expect(shell.current_path).to eq("ModelRoot::Package")
        end

        it "shows error for non-existent bookmark" do
          expect {
            shell.send(:bookmark_go, "nonexistent")
          }.to output(/not found/).to_stdout
        end
      end

      describe "#bookmark_remove" do
        before do
          shell.instance_variable_set(:@bookmarks, { "test" => "Path" })
        end

        it "removes bookmark" do
          expect {
            shell.send(:bookmark_remove, "test")
          }.to output(/removed/).to_stdout

          expect(shell.bookmarks).not_to have_key("test")
        end

        it "shows error for non-existent bookmark" do
          expect {
            shell.send(:bookmark_remove, "nonexistent")
          }.to output(/not found/).to_stdout
        end
      end
    end

    describe "#cmd_results" do
      it "shows last results" do
        shell.instance_variable_set(:@last_results, ["Class1", "Class2"])

        expect {
          shell.send(:cmd_results, [])
        }.to output(/Class1/).to_stdout
         .and output(/Class2/).to_stdout
      end

      it "shows warning when no results" do
        expect {
          shell.send(:cmd_results, [])
        }.to output(/No previous results/).to_stdout
      end
    end

    describe "#cmd_stats" do
      it "displays repository statistics" do
        expect {
          shell.send(:cmd_stats, [])
        }.to output(/5/).to_stdout
         .and output(/20/).to_stdout
      end
    end

    describe "#cmd_config" do
      it "displays current configuration" do
        expect {
          shell.send(:cmd_config, [])
        }.to output(/Configuration/).to_stdout
         .and output(/color/).to_stdout
         .and output(/icons/).to_stdout
      end
    end

    describe "#cmd_clear" do
      it "sends clear screen sequence" do
        expect {
          shell.send(:cmd_clear, [])
        }.to output(/\e\[2J\e\[H/).to_stdout
      end
    end

    describe "#cmd_help" do
      it "displays general help" do
        expect {
          shell.send(:cmd_help, [])
        }.to output(/Available Commands/).to_stdout
         .and output(/Navigation/).to_stdout
         .and output(/Query/).to_stdout
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