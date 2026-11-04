# frozen_string_literal: true

require "benchmark"
require "json"
require "tmpdir"
require "fileutils"

module Expressir
  # The per-command scoreboard (TODO.compat/03): interleaved CPU-time
  # medians per measured command, published per release and gated
  # against a committed baseline (`rake scoreboard:gate`).
  #
  # Lanes: the two shipped parse engines (native core, Ruby grammar)
  # for the parse row; single-lane rows for the composite commands
  # (compare, population validate, flatten). Optional cross-tool rows
  # activate when a reference binary is provided via the environment.
  module Scoreboard
    REPS = 9

    # CPU time where the platform provides it (Windows Ruby carries no
    # CLOCK_PROCESS_CPUTIME_ID — monotonic keeps the gate usable).
    CLOCK = if Process.const_defined?(:CLOCK_PROCESS_CPUTIME_ID)
              Process::CLOCK_PROCESS_CPUTIME_ID
            else
              Process::CLOCK_MONOTONIC
            end

    module_function

    # @return [Hash] command => { reps:, cpu: [median seconds] }
    def run(reps: REPS, warmup: 1)
      prepare_fixtures
      rows = {}
      rows["parse (native)"] = measure(warmup, reps) { native_parse }
      rows["parse (ruby)"] = measure(warmup, reps) { ruby_parse }
      rows["compare"] = measure(warmup, reps) { run_compare }
      rows["validate"] = measure(warmup, reps) { run_validate }
      rows["flatten"] = measure(warmup, reps) { run_flatten }
      rows
    end

    def table(rows)
      lines = ["| Row | CPU median (s) |", "| --- | --- |"]
      rows.each { |row, cpu| lines << "| #{row} | #{format('%.4f', cpu)} |" }
      lines.join("\n")
    end

    def median(values)
      sorted = values.sort
      mid = sorted.length / 2
      sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end

    def measure(warmup, reps, &)
      warmup.times(&)
      cpu = []
      reps.times do
        t0 = Process.clock_gettime(CLOCK)
        yield
        cpu << (Process.clock_gettime(CLOCK) - t0)
      end
      median(cpu)
    end

    def prepare_fixtures
      dir = File.join(Dir.tmpdir, "expressir-scoreboard")
      FileUtils.mkdir_p(dir)
      @schema_path = File.join(dir, "scoreboard.exp")
      File.write(@schema_path, SCOREBOARD_SCHEMA)
      @base_path = File.join(dir, "base.exp")
      File.write(@base_path, SCOREBOARD_SCHEMA)
      @revised_path = File.join(dir, "revised.exp")
      File.write(@revised_path, SCOREBOARD_SCHEMA_REVISED)
      @p21_path = File.join(dir, "scoreboard.p21")
      File.write(@p21_path, SCOREBOARD_P21)
      @schema_path
    end

    def native_parse
      Expressir::Express::Parser.from_file(@schema_path, use_native: true,
                                                         skip_references: true)
    end

    def ruby_parse
      Expressir::Express::Parser.from_file(@schema_path, use_native: false,
                                                         skip_references: true)
    end

    def run_compare
      base = Expressir::Express::Parser.from_exp(SCOREBOARD_SCHEMA,
                                                 skip_references: true).schemas.first
      revised = Expressir::Express::Parser.from_exp(SCOREBOARD_SCHEMA_REVISED,
                                                    skip_references: true).schemas.first
      Expressir::Express::SchemaCompare.compare(base, revised)
    end

    def run_validate
      population = Expressir::P21::Parser.parse(SCOREBOARD_P21)
      schema = Expressir::Express::Parser.from_exp(SCOREBOARD_SCHEMA,
                                                   skip_references: true).schemas.first
      Expressir::P21::Validator.validate(population, schema)
    end

    def run_flatten
      repo = Expressir::Express::Parser.from_file(@schema_path, skip_references: true)
      schema = repo.schemas.first
      Expressir::Express::Shtolo.new(schema, repo).flatten if schema
    end

    SCOREBOARD_SCHEMA = <<~EXPRESS
      SCHEMA scoreboard;
        ENTITY point;
          x : REAL;
          y : REAL;
        END_ENTITY;
        ENTITY colour;
          name : STRING;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS

    SCOREBOARD_SCHEMA_REVISED = <<~EXPRESS
      SCHEMA scoreboard;
        ENTITY point;
          x : REAL;
          y : REAL;
          z : REAL;
        END_ENTITY;
        ENTITY colour;
          name : STRING;
        END_ENTITY;
        ENTITY marker;
          at : point;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS

    SCOREBOARD_P21 = <<~P21
      ISO-10303-21;
      HEADER;
      FILE_NAME('sb','2026-10-23T00:00:00',(''),(''),'','','');
      FILE_SCHEMA(('SCOREBOARD'));
      ENDSEC;
      DATA;
      #1=POINT(1.0,2.0);
      #2=POINT(3.0,4.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
  end
end
