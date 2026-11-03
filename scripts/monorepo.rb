#!/usr/bin/env ruby
# frozen_string_literal: true

# Monorepo helper for CI and release workflows (lutaml/lutaml#232).
#
#   scripts/monorepo.rb list                  # JSON array of package names
#   scripts/monorepo.rb version <package>     # version from the gemspec
#   scripts/monorepo.rb tag <package>         # <package>-v<version>
#   scripts/monorepo.rb package-of <tag>      # package a release tag belongs to
#   scripts/monorepo.rb check-tag <tag>       # tag matches the gemspec version
#   scripts/monorepo.rb bump <package> <next> # x.y.z | major | minor | patch
#
# A package is a directory packages/<name> holding <name>.gemspec. Tags are
# "<name>-v<version>"; the longest matching package name wins, so
# "lutaml-model-v1.0.0" never resolves to the "lutaml" package.
require "json"
require "rubygems"

module Monorepo
  class Error < StandardError; end

  ROOT = File.expand_path("..", __dir__)
  BUMPS = %w[major minor patch].freeze

  module_function

  def packages(root = ROOT)
    Dir.glob(File.join(root, "packages", "*", "*.gemspec")).filter_map do |path|
      dir = File.basename(File.dirname(path))
      dir if File.basename(path, ".gemspec") == dir
    end.sort
  end

  def package_dir(name, root = ROOT)
    unless packages(root).include?(name)
      raise Error, "unknown package #{name.inspect} (known: #{packages(root).join(', ')})"
    end

    File.join(root, "packages", name)
  end

  def version_file(name, root = ROOT)
    dir = package_dir(name, root)
    gemspec = File.read(File.join(dir, "#{name}.gemspec"))
    # `require_relative "lib/x/version"` or `require "x/version"` (lib/ on the load path)
    match = gemspec.match(%r{^require(_relative)?\s+["']([^"']*version)["']})
    raise Error, "#{name}: no version file required by its gemspec" unless match

    relative = match[1] ? match[2] : "lib/#{match[2]}"
    File.join(dir, "#{relative}.rb")
  end

  def version(name, root = ROOT)
    text = File.read(version_file(name, root))
    text[/VERSION\s*=\s*["']([^"']+)["']/, 1] ||
      raise(Error, "#{name}: no VERSION constant in #{version_file(name, root)}")
  end

  def tag(name, root = ROOT)
    "#{name}-v#{version(name, root)}"
  end

  def package_of(tag, root = ROOT)
    match = packages(root).select { |name| tag.start_with?("#{name}-v") }
      .max_by(&:length)
    raise Error, "tag #{tag.inspect} matches no package prefix" unless match

    match
  end

  def check_tag(tag, root = ROOT)
    name = package_of(tag, root)
    expected = tag(name, root)
    return name if tag == expected

    raise Error, "tag #{tag} does not match #{name} gemspec version (expected #{expected})"
  end

  def next_version(current, request)
    return request if request.match?(/\A\d+\.\d+\.\d+(\.[0-9A-Za-z.]+)?\z/)
    raise Error, "bad version request #{request.inspect}" unless BUMPS.include?(request)

    major, minor, patch = current.split(".").first(3).map(&:to_i)
    case request
    when "major" then "#{major + 1}.0.0"
    when "minor" then "#{major}.#{minor + 1}.0"
    else "#{major}.#{minor}.#{patch + 1}"
    end
  end

  def bump(name, request, root = ROOT)
    current = version(name, root)
    target = next_version(current, request)
    file = version_file(name, root)
    File.write(file, File.read(file).sub(/(VERSION\s*=\s*["'])#{Regexp.escape(current)}(["'])/,
                                         "\\1#{target}\\2"))
    target
  end

  def run(argv, out: $stdout)
    command, *args = argv
    case command
    when "list" then out.puts JSON.generate(packages)
    when "version" then out.puts version(args.fetch(0))
    when "tag" then out.puts tag(args.fetch(0))
    when "package-of" then out.puts package_of(args.fetch(0))
    when "check-tag" then out.puts check_tag(args.fetch(0))
    when "bump" then out.puts bump(args.fetch(0), args.fetch(1))
    else raise Error, "usage: monorepo.rb list|version|tag|package-of|check-tag|bump ..."
    end
    0
  rescue Error, IndexError => e
    warn e.message
    1
  end
end

exit Monorepo.run(ARGV) if $PROGRAM_NAME == __FILE__
