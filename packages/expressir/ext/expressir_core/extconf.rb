# frozen_string_literal: true

require "mkmf"

# mkmf's dummy_makefile emits no targets, which rubygems' `make` run
# rejects ("No targets. Stop.") and fails the install; a real no-op
# makefile keeps every fallback path installing cleanly.
def write_noop_makefile
  File.write("Makefile", <<~MK)
    all:
    install:
    clean:
  MK
end

# The Rust extension only builds against MRI's C API. Other engines
# fall back to the pure-Ruby parser path and must install cleanly.
if RUBY_ENGINE != "ruby" || ENV["EXPRESSIR_CORE"] == "0"
  write_noop_makefile
  warn "expressir: skipping the Rust core extension on #{RUBY_ENGINE}"
  exit 0
end

# Local mingw rubies pair with an msvc-default cargo and cannot build;
# cross-build environments (rake-compiler sets RUBY_CC_VERSION there —
# extconf runs under the cross mingw ruby) carry the coherent gnu
# toolchain and MUST build: the prebuilt platform gems come from them.
# EXPRESSIR_CORE_FORCE=1 remains the manual override.
if RUBY_PLATFORM.include?("mingw") && ENV["EXPRESSIR_CORE_FORCE"] != "1" &&
    !ENV.key?("RUBY_CC_VERSION")
  write_noop_makefile
  warn "expressir: skipping the Rust core extension on mingw (msvc " \
       "toolchain mismatch)"
  exit 0
end

# Pure-Ruby fallback when no Rust toolchain is available: the gem must
# install and keep working without the native core
# (Expressir::Core::NATIVE_AVAILABLE stays false). Prebuilt platform
# gems are the follow-up so cargo-less MRI installs get binaries too.
unless find_executable("cargo")
  write_noop_makefile
  warn "expressir: cargo not found — skipping the Rust core extension " \
       "(Expressir::Core falls back to the Ruby parser)"
  exit 0
end

require "rb_sys/mkmf"

create_rust_makefile("expressir/expressir_core") do |r|
  r.profile = ENV.fetch("RB_SYS_CARGO_PROFILE", :dev).to_sym
  r.use_stable_api_compiled_fallback = true
  r.force_install_rust_toolchain = false
end
