# frozen_string_literal: true

require "cgi"
require "pathname"
require "set"
require "uri"
require "yaml"

config = YAML.safe_load(File.read(ARGV.fetch(0)))
site = Pathname.new(ARGV.fetch(1)).realpath
origin = URI(config.fetch("url"))
base = config.fetch("baseurl", "").sub(%r{/$}, "")
hosts = [origin.host, "lutaml.github.io"]
checked = Set.new
errors = []

site.glob("**/*.html").each do |file|
  File.read(file).scan(/\b(?:href|src)=["']([^"']+)["']/).flatten.each do |value|
    uri = URI(CGI.unescapeHTML(value))
    own_url = %w[http https].include?(uri.scheme) && hosts.include?(uri.host)
    local_url = uri.scheme.nil? && uri.host.nil?
    next unless own_url || local_url

    if local_url && uri.path.start_with?("/") && !base.empty? &&
        uri.path != base && !uri.path.start_with?("#{base}/")
      errors << "#{file.relative_path_from(site)}: #{value} is outside baseurl #{base}"
      next
    end

    if own_url || uri.path.start_with?("/")
      next if own_url && uri.path != base && !uri.path.start_with?("#{base}/")
      path = URI::DEFAULT_PARSER.unescape(uri.path.delete_prefix(base)).sub(%r{^/}, "")
      target = site.join(path).cleanpath
    else
      target = uri.path.empty? ? file : file.dirname.join(URI::DEFAULT_PARSER.unescape(uri.path)).cleanpath
    end
    target = target.join("index.html") if target.directory?
    key = "#{target}##{uri.fragment}"
    next unless checked.add?(key)

    if !target.to_s.start_with?("#{site}/") || !target.file? || !target.realpath.to_s.start_with?("#{site}/")
      errors << "#{file.relative_path_from(site)}: #{value} has no built target"
    elsif uri.fragment && !uri.fragment.empty?
      anchors = File.read(target).scan(/\b(?:id|name)=["']([^"']+)["']/).flatten
      fragment = URI::DEFAULT_PARSER.unescape(uri.fragment)
      errors << "#{file.relative_path_from(site)}: #{value} has no built anchor" unless anchors.include?(fragment)
    end
  rescue URI::InvalidURIError
    errors << "#{file.relative_path_from(site)}: invalid URL #{value}"
  end
end
abort "No site URLs found in #{site}" if checked.empty?
abort errors.join("\n") unless errors.empty?
puts "Verified #{checked.size} built local/canonical targets and anchors"
