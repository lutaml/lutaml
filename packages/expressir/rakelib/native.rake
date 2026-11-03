# frozen_string_literal: true

# Prebuilt platform gems (TODO.suma-improvements/01): the compiled Rust
# core ships inside per-platform gems, mirroring the parsanol-ruby
# pattern (RbSys::ExtensionTask + cross_compiling staging). The source
# gem keeps its gemspec-declared extconf build; platform gems carry the
# artifact in lib/expressir/, which core.rb's first require finds.
begin
  require "rb_sys/extensiontask"

  gemspec = Gem::Specification.load("expressir.gemspec")

  RbSys::ExtensionTask.new("expressir_core", gemspec) do |ext|
    ext.lib_dir = "lib/expressir"
    # rb-sys stages the cross-built artifact itself; a manual cp into
    # lib_dir here would claim the file rake-compiler's own
    # copy:expressir_core:<host-platform> task owns, and the cross gem's
    # dependency chain would then force a host-ruby build (rb-sys
    # refuses windows bindings from linux headers).
  end
rescue LoadError
  # rake-compiler/rb_sys not installed (consumer checkouts); the native
  # gem tasks are a maintainer/CI concern only.
end
