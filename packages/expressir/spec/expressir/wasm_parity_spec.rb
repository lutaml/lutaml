# frozen_string_literal: true

require "spec_helper"
require "json"

# TODO.compat/08: the WASM expressir-rs package validates a schema and
# a P21 population with parity to the native path on the P21
# conformance corpus (annexes E/H/I/J).
#
# The package is built from lutaml/expressir-rs (wasm-pack build
# --target nodejs --release --out-dir <dir>); point EXPRESSIR_WASM_DIR
# at it. Skipped when the build or a node runtime is absent — the
# parity contract itself is asserted whenever the package is present.
RSpec.describe "expressir-rs wasm parity" do # rubocop:disable RSpec/DescribeClass
  let(:wasm_dir) do
    ENV.fetch("EXPRESSIR_WASM_DIR",
              File.expand_path("../../tmp/expressir-wasm", __dir__))
  end

  let(:wasm_ready) do
    File.exist?(File.join(wasm_dir, "expressir_rs.js")) &&
      system("node", "--version", out: File::NULL)
  end

  it "validates the schema and populations with native parity" do
    skip "no wasm package at #{wasm_dir} (wasm-pack build) or no node" unless wasm_ready

    script = <<~JS
      const input = JSON.parse(process.argv[1]);
      const wasm = require(input.wasm + "/expressir_rs.js");
      const fs = require("fs");
      const path = require("path");
      const results = {};
      const schemaSource = fs.readFileSync(
        path.join(input.corpus, "annex_h_schema.exp"), "utf8");
      const schemas = JSON.parse(wasm.parse_schema(schemaSource));
      results.schema_name = schemas[0].name;
      results.entities = schemas.flatMap((s) => s.entities.map((e) => e.name));
      results.files = {};
      for (const file of [
        "conformance/annex-e-0.p21", "conformance/annex-e-1.p21",
        "conformance/annex-h-0.p21", "conformance/annex-i-0.p21",
        "conformance/annex-i-1.p21", "conformance/annex-j-0.p21",
      ]) {
        const source = fs.readFileSync(path.join(input.corpus, file), "utf8");
        const population = JSON.parse(wasm.parse_population(source));
        results.files[file] = {
          file_schemas: population.file_schemas,
          records: population.records.length,
          anchors: population.anchors,
          references: population.references,
        };
      }
      const annexH = fs.readFileSync(path.join(input.corpus, "annex_h.p21"), "utf8");
      const inventory = results.entities.concat(
        ["cpt", "ed", "ed_loop", "ed_strc", "vx"]);
      results.annex_h_verdict = JSON.parse(
        wasm.validate_population(JSON.stringify(inventory), annexH));
      const bad = JSON.parse(wasm.validate_population(
        JSON.stringify(["no_such_entity"]), annexH));
      results.bad_verdict_valid = bad.valid;
      console.log("@@JSON@@" + JSON.stringify(results));
    JS

    args = JSON.generate(wasm: File.expand_path(wasm_dir),
                         corpus: File.expand_path("spec/fixtures/p21"))
    out = `node -e '#{script}' '#{args}' 2>&1`
    raise "node run failed: #{out}" unless $?.success?

    wasm_results = JSON.parse(out[/@@JSON@@(.*)\z/m, 1])

    schema = Expressir::Express::Parser.from_file("spec/fixtures/p21/annex_h_schema.exp")
    expect(wasm_results["schema_name"].downcase)
      .to eq(schema.schemas.first.id.downcase)
    expect(wasm_results["entities"].map(&:downcase))
      .to eq(schema.schemas.first.entities.map { |e| e.id.downcase })

    corpus = {
      "conformance/annex-e-0.p21" => { records: 5, anchors: {}, references: {} },
      "conformance/annex-e-1.p21" => { records: 5, anchors: {}, references: {} },
      "conformance/annex-h-0.p21" => { records: 13, anchors: {}, references: {} },
      "conformance/annex-i-0.p21" => { records: 14,
                                       anchors: { "POINT_1" => "#1", "POINT_2" => "#2",
                                                  "POINT_3" => "#3", "POINT_4" => "#4",
                                                  "POINT_5" => "#5", "POINT_6" => "$" },
                                       references: {
                                         "#11" => "<ftp://ftp.acme.net/second_file.stp#vertex_1>",
                                       } },
      "conformance/annex-i-1.p21" => { records: 1,
                                       anchors: { "vertex_1" => "#11" },
                                       references: {
                                         "#1" => "<http://www.giant.com/first_file.stp#POINT_1>",
                                       } },
      "conformance/annex-j-0.p21" => { records: 1, anchors: {}, references: {} },
    }
    corpus.each do |file, expected|
      source = File.read(File.join("spec/fixtures/p21", file))
      native = Expressir::P21::Parser.parse(source)
      wasm_file = wasm_results["files"][file]

      expect(wasm_file["file_schemas"])
        .to eq(Array(native.header["FILE_SCHEMA"]).flatten)
      expect(wasm_file["records"]).to eq(expected[:records])
      expect(wasm_file["records"]).to eq(native.instances.size)
      expect(wasm_file["anchors"].to_h).to eq(expected[:anchors])
      # the native model types the promissory `$` marker as :unset;
      # the wasm surface carries the source text
      native_anchors = native.anchors.transform_values do |value|
        value == :unset ? "$" : value
      end
      expect(native_anchors).to eq(expected[:anchors])
      expect(wasm_file["references"].count).to eq(expected[:references].size)
      expect(native.references).to eq(expected[:references])
    end

    # the schema inventory validates the annex H population; a bogus
    # inventory rejects it (ISO 10303-21 clause 12)
    expect(wasm_results["annex_h_verdict"]["valid"]).to be(true)
    expect(wasm_results["bad_verdict_valid"]).to be(false)
  end
end
