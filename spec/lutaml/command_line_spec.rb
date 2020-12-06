require "spec_helper"
require "lutaml/command_line"

RSpec.describe Lutaml::CommandLine do
  describe ".run" do
    subject(:run) { described_class.run(args, output) }

    let(:output) { StringIO.new }

    context "when --help flag" do
      let(:args) { ["--help"] }
      let(:help_message) do
        File.read(fixtures_path("help_message.txt"))
      end

      it "returns help message" do
        expect do
          # rubocop:disable Lint/RescueException
          begin
            run
          rescue Exception => e
            expect(e).to(be_instance_of(SystemExit))
          end
          # rubocop:enable Lint/RescueException
        end.to(change do
          output.rewind
          output.read
        end.to(help_message))
      end
    end

    context "when lutaml files passed" do
      context "when one file passed without args" do
        let(:args) { [fixtures_path("test.lutaml")] }
        let(:result_dot_string) do
          File.read(fixtures_path("test.dot"))
        end

        it "generates dot from lutaml" do
          expect { run }
            .to(change do
              output.rewind
              output.read
            end.to(result_dot_string))
        end
      end

      context "when one file passed with -o . flag" do
        let(:lutaml_path) { assets_path("test.lutaml") }
        let(:result_dot_path) { "test.dot" }
        let(:args) { ["-o", ".", lutaml_path] }
        let(:result_dot_string) do
          File.read(fixtures_path("test.dot"))
        end

        around do |example|
          File.open(lutaml_path, "w") do |f|
            f.puts(File.read(fixtures_path("test.lutaml")))
          end
          example.run
          FileUtils.rm_f(lutaml_path)
          FileUtils.rm_f(result_dot_path)
        end

        it "generates test.dot file in current directorylutaml" do
          expect { run }
            .to(change do
              File.file?(result_dot_path)
            end.from(false).to(true))
        end

        context "when -o flag points to a different directory" do
          let(:result_dot_path) { assets_path("test.dot") }
          let(:args) { ["-o", assets_path(""), lutaml_path] }

          it "generates test.dot file in another directory" do
            expect { run }
              .to(change do
                File.file?(result_dot_path)
              end.from(false).to(true))
          end
        end
      end
    end
  end
end
