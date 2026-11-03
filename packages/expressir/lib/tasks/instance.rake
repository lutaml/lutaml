# frozen_string_literal: true

namespace :instance do
  desc "Population rule-engine benchmark over a synthetic population " \
       "(default 100000 instances; POPULATION_SIZE to override)"
  task :benchmark do
    require "expressir"
    require "expressir/eval"
    require "json"
    require "tmpdir"

    size = Integer(ENV.fetch("POPULATION_SIZE", "100 000").delete(" "), 10)
    out = ENV["INSTANCE_BENCH_OUT"] || "instance-benchmark.json"

    Dir.mktmpdir do |dir|
      schema_path = File.join(dir, "bench.exp")
      File.write(schema_path, <<~EXP)
        SCHEMA bench;
        ENTITY item;
          code : INTEGER;
          ref : item;
        UNIQUE
          u1 : code;
        END_ENTITY;
        RULE no_negative_codes FOR (item);
          WHERE
            ok : SIZEOF(QUERY(i <* item | i.code < 0)) = 0;
        END_RULE;
        END_SCHEMA;
      EXP

      population_path = File.join(dir, "bench.p21")
      File.open(population_path, "w") do |file|
        file.puts "ISO-10303-21;"
        file.puts "HEADER;"
        file.puts "FILE_NAME('bench','2026-01-01T00:00:00',('b'),('b')," \
                  "'p','s','a');"
        file.puts "FILE_SCHEMA(('bench'));"
        file.puts "ENDSEC;"
        file.puts "DATA;"
        size.times do |i|
          ref = i.zero? ? "$" : "##{i}"
          file.puts "##{i + 1}=ITEM(#{i},#{ref});"
        end
        file.puts "ENDSEC;"
        file.puts "END-ISO-10303-21;"
      end

      clock = Process.method(:clock_gettime)
      mono = Process::CLOCK_MONOTONIC
      t0 = clock.call(mono)
      schema = Expressir::Express::Parser.from_file(schema_path).schemas.first
      population = Expressir::P21::Parser.parse(File.read(population_path))
      timings = { load: (clock.call(mono) - t0).round(2) }

      engine = Expressir::Eval::Population.new(schema, population)
      t1 = clock.call(mono)
      first = engine.check
      timings[:check_first] = (clock.call(mono) - t1).round(2)
      t2 = clock.call(mono)
      second = engine.check
      timings[:check_second] = (clock.call(mono) - t2).round(2)

      report = {
        instances: size,
        rules: { where: 0, unique: 1, global: 1 },
        findings: first.size,
        deterministic: first == second,
        timings_seconds: timings,
      }
      File.write(out, "#{JSON.pretty_generate(report)}\n")
      puts "wrote #{out} (#{size} instances, findings #{first.size}, " \
           "check #{timings[:check_first]}s, " \
           "deterministic=#{report[:deterministic]})"
    end
  end
end
