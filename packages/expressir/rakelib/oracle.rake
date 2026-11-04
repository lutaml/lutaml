# frozen_string_literal: true

require "digest"
require "fileutils"

ORACLE_TAG = "eeng-5.2.8"
ORACLE_BASE =
  "https://github.com/expresslang/eengine-releases/releases/download/#{ORACLE_TAG}".freeze
# Release-asset naming convention for the pinned tag: platform prefix
# and CPU tag used by expresslang/eengine-releases.
ORACLE_ASSET_NAMES = {
  %w[darwin arm64] => "mac-arm64",
  %w[darwin x86_64] => "mac-x86-64",
  %w[linux x86_64] => "lnx-x86-64",
  %w[linux arm64] => "lnx-arm64",
  %w[mingw x86_64] => "win-x86-64",
}.freeze

namespace :oracle do
  desc "Fetch the eengine oracle (#{ORACLE_TAG}) into tmp/oracle/eengine " \
       "for the SHTOLO corpus differential"
  task :fetch do
    platform = [Gem::Platform.local.os, Gem::Platform.local.cpu]
    tag = ORACLE_ASSET_NAMES[platform]
    abort "no #{ORACLE_TAG} asset for #{platform.join('-')}" unless tag

    version = ORACLE_TAG.delete_prefix("eeng-")
    asset = "eengine-#{version}-#{tag}-sbcl#{'.exe' if platform.first == 'mingw'}"
    target = File.expand_path("../tmp/oracle/eengine", __dir__)
    digest = "#{target}.sha256"

    if File.executable?(target)
      expected = File.read(digest).strip.split(/\s+/).first if File.exist?(digest)
      if expected && Digest::SHA256.file(target).hexdigest == expected
        warn "oracle already present: #{target}"
        exit 0
      end
      warn "cached oracle is missing or corrupt; refetching"
      rm_f target
    end

    dir = File.dirname(target)
    mkdir_p dir
    download = File.join(dir, "#{asset}.part")
    sh "curl", "-fSL", "-o", download, "#{ORACLE_BASE}/#{asset}"
    sha = Digest::SHA256.file(download).hexdigest
    mv download, target
    chmod 0o755, target
    File.write(digest, "#{sha}  eengine\n")
    puts "oracle ready: #{target} (#{sha})"
  end
end
