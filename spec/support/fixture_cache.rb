# frozen_string_literal: true

# Memoizes parsed fixtures across all specs to avoid redundant I/O and parsing.
module FixtureCache
  CACHE = {} # rubocop:disable Style/MutableConstant

  def cached_xmi_document(path = "ea-xmi-2.5.1.xmi", fixture: true)
    key = :"xmi:#{path}"
    CACHE[key] ||= begin
      resolved = fixture ? fixtures_path(path) : path
      Lutaml::Xmi::Parsers::Xml.parse(File.new(resolved))
    end
  end

  def cached_repository(path = "ea-xmi-2.5.1.xmi")
    key = :"repo:#{path}"
    CACHE[key] ||= begin
      document = cached_xmi_document(path)
      Lutaml::UmlRepository::Repository.new(document: document)
    end
  end

  def cached_qea_parse(path, **options)
    key = :"qea:#{path}:#{options.hash}"
    CACHE[key] ||= Lutaml::Qea.parse(path, **options)
  end

  def cached_qea_database(path, **options)
    key = :"qea_db:#{path}:#{options.hash}"
    CACHE[key] ||= Lutaml::Qea::Services::DatabaseLoader
      .new(path, options[:config]).load
  end

  def fresh_xmi_document(path = "ea-xmi-2.5.1.xmi")
    Lutaml::Xmi::Parsers::Xml.parse(File.new(fixtures_path(path)))
  end

  def fresh_repository(path = "ea-xmi-2.5.1.xmi")
    Lutaml::UmlRepository::Repository.new(document: fresh_xmi_document(path))
  end
end

RSpec.configure do |config|
  config.include FixtureCache
end
