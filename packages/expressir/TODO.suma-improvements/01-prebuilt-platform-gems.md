# 01 — Prebuilt platform gems

## Goal
`gem install expressir` compiles nothing on machines with a prebuilt
platform gem: the binding binary ships inside per-platform gems
(`expressir-<ver>-arm64-darwin` etc.), following the parsanol-ruby
pattern (oxidize-rb cross-gem + RbSys::ExtensionTask).

## Pattern (from ~/src/parsanol/parsanol-ruby)
- `oxidize-rb/actions/fetch-ci-data@v1` computes supported platforms
- `oxidize-rb/actions/cross-gem@v1` matrix builds per-platform gems in
  rake-compiler-dock containers (coherent gnu toolchain per target —
  this is what fixes windows)
- per-platform smoke jobs on REAL runners installing the gem and running
  a smoke script (NATIVE true + parse)
- source gem still builds via the gemspec (extensions stay declared);
  rubygems prefers a matching platform gem automatically

## expressir implementation
- `rakelib/native.rake`: `RbSys::ExtensionTask.new("expressir_core")`,
  `ext.lib_dir = "lib/expressir"`, `cross_compiling` callback stages
  `expressir_core.{so,dylib,dll}` into `lib/expressir/` (loads via the
  existing first `require "expressir/expressir_core"` in core.rb)
- extconf: mingw skip becomes bypassable (`EXPRESSIR_CORE_FORCE=1` set in
  the cross-gem container, where cargo gnu matches the mingw-ucrt ruby)
- `.github/workflows/native-gems.yml`: ci-data + cross-gem matrix +
  smoke jobs + source gem + `gem push` on tag (RUBYGEMS_API_KEY secret)
- `.github/scripts/test_installed_gem.rb`: smoke script

## Acceptance
- workflow green across platforms with smoke jobs passing
- a platform gem installs cargo-less and reports NATIVE true
- source-gem install path unchanged (2.4.21 behavior)
