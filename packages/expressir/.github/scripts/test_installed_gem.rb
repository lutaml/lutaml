# frozen_string_literal: true

# Smoke test for an INSTALLED expressir gem (run after `gem install`,
# never from the source directory): the Rust core binding must be
# active and the parser must handle the standard and #462 forms.
require "expressir"

if Gem.win_platform? && !Expressir::Express::Core::NATIVE_AVAILABLE
  # Interim expressir#487 guard: native is intentionally disabled on
  # windows until the ancestor-walk fix (#499) merges and the guard
  # reverts. The platform gem must still SHIP a loadable extension -
  # that is this leg's contract while the guard stands.
  gem_dir = Gem.loaded_specs["expressir"].gem_dir
  shipped = Dir.glob(File.join(gem_dir, "**", "expressir_core.{so,dll}"))
  abort "FAIL: expressir_core not shipped in the platform gem" if shipped.empty?
  puts "native binding: deferred (windows guard, expressir#487)"
else
  abort "FAIL: NATIVE_AVAILABLE is false" unless Expressir::Express::Core::NATIVE_AVAILABLE
  puts "native binding: active"
end

repo = Expressir::Express::Parser.from_exp(
  "SCHEMA smoke; ENTITY e; a : STRING; END_ENTITY; END_SCHEMA;",
)
abort "FAIL: schema not parsed" unless repo.schemas.first.id == "smoke"
puts "standard parse: ok"

src = <<~EXP
  SCHEMA m;
  ENTITY e; END_ENTITY;
  SUBTYPE_CONSTRAINT c FOR e;
    ABSTRACT;
  END_SUBTYPE_CONSTRAINT;
  END_SCHEMA;
EXP
sc = Expressir::Express::Parser.from_exp(src).schemas.first.subtype_constraints.first
abort "FAIL: subtype constraint ABSTRACT body (#462)" unless sc&.abstract == true
puts "#462 form: ok"

# The platform gems force-build the Rust compiled-set writer; a leg that
# shipped a non-loadable expressir_core would otherwise pass this smoke.
# Windows under the #487 guard runs the pure-Ruby fallback instead.
unless Gem.win_platform? && !Expressir::Express::Core::NATIVE_AVAILABLE
  abort "FAIL: core_set_available is false" unless Expressir::Express::Parser.core_set_available?
  puts "compiled-set core: ok"
end

puts "SMOKE OK"
