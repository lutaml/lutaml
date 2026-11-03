# frozen_string_literal: true

# Engine benchmark: leptris vs nokogiri through Moxml, on a real corpus.
#
#   ADAPTER=leptris bundle exec ruby benchmark/engines.rb
#
# Per-adapter numbers land on stdout as `key: value` lines; the rake task
# (`rake benchmark:engines`) runs both adapters for side-by-side recording
# in TODO.performance.md.

require "benchmark"
require "tmpdir"
require "fileutils"

ADAPTER = ENV.fetch("ADAPTER", "leptris")

require "rng" if ADAPTER == "leptris" # load first so Moxml picks it
require "lutaml/xsd"

def corpus_path
  corpus = File.join(__dir__, "..", "tmp", "bench_corpus.xsd")
  unless File.exist?(corpus)
    rnc = File.expand_path(
      "../spec/fixtures/metanorma-model-iso-grammars/bsi.rnc", __dir__
    )
    grammar = Rng.parse_file(rnc)
    schema = Lutaml::Xsd::RngToXsdConverter.new(grammar, file_path: rnc).convert
    FileUtils.mkdir_p(File.dirname(corpus))
    File.write(corpus, schema.to_xml)
  end
  corpus
end

def measure(label, iterations: 5, &)
  gc_was = GC.enable
  GC.start
  elapsed = Benchmark.realtime { iterations.times(&) }
  GC.start if gc_was
  format("%-34s %8.1f ms/op", label, (elapsed / iterations) * 1000)
end

corpus = File.read(corpus_path)
ctx = Moxml::Context.new(ADAPTER.to_sym)

puts "adapter: #{ADAPTER}"
puts "corpus_bytes: #{corpus.bytesize}"

# Engine-level parse
doc = nil
puts measure("engine_parse") { doc = ctx.parse(corpus) }

# Engine-level XPath
puts measure("engine_xpath_elements") { doc.xpath("//*[local-name() = 'element']") }

# Engine-level serialize
puts measure("engine_serialize") { doc.to_xml }

# Schema pipeline parse (lutaml-model over Moxml)
Lutaml::Xml::Schema::Xsd.parse(corpus) # warm autoloads/registration
schema = nil
puts measure("pipeline_schema_parse") { schema = Lutaml::Xml::Schema::Xsd.parse(corpus) }

# Schema model serialization
puts measure("pipeline_schema_to_xml") { schema.to_xml }

# Compiled-schema instance validation (tier-1 engines)
instance = <<~XML
  <bible xmlns="http://example.com/bsi"><content><section-title>t</section-title></content></bible>
XML
begin
  compiled = ctx.xsd(corpus)
  puts measure("engine_xsd_compile", iterations: 3) { ctx.xsd(corpus) }
  puts measure("engine_xsd_validate") { compiled.validate(instance) }
rescue StandardError => e
  puts "engine_xsd_compile                   n/a (#{e.class})"
  puts "engine_xsd_validate                  n/a (#{e.class})"
end
