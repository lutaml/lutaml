# frozen_string_literal: true

module Expressir
  module Commands
    # `expressir mapping validate` (#88): load a module mapping.yaml,
    # resolve every <<express:...>> link and every reference path
    # against the ARM/MIM interface closure. Exits 1 when unknown
    # links or refpath issues remain.
    class MappingValidate < Base
      def run(path)
        document = Expressir::Mapping.load_file(path)
        repository = repository_for(path)

        unknown = Expressir::Mapping.unknown_links(document, repository)
        unknown.each do |link|
          say "unknown: #{link.text}"
        end

        issues = refpath_issues(document, repository)
        issues.each do |location, issue|
          say "refpath #{location} [step #{issue.step}]: #{issue.message}"
        end

        rule_issues = Expressir::Mapping.rule_issues(document, repository)
        rule_issues.each do |missing|
          say "unknown rule: #{missing.text}"
        end

        total = unknown.size + issues.size + rule_issues.size
        unless total.zero?
          raise Thor::Error, "#{unknown.size} unknown link(s), " \
                             "#{issues.size} refpath issue(s), " \
                             "#{rule_issues.size} unknown rule(s)"
        end

        say "all links and reference paths resolve"
      end

      private

      def refpath_issues(document, repository)
        Expressir::Mapping.refpaths(document).flat_map do |location, content|
          parsed = Expressir::Mapping::RefPath.parse(content)
          start = Expressir::Mapping.entity_item(location)
          parsed.parse_errors.map do |error|
            [location, Expressir::Mapping::RefPath::Issue.new(step: nil,
                                                              message: error)]
          end + Expressir::Mapping::RefPath.validate(parsed, repository,
                                                     start: start)
            .map { |issue| [location, issue] }
        end
      end

      def repository_for(path)
        dir = File.dirname(File.expand_path(path))
        arm = Dir[File.join(dir, "arm.exp")].first
        mim = Dir[File.join(dir, "mim.exp")].first
        roots = [arm, mim].compact
        raise Thor::Error, "no arm.exp/mim.exp next to #{path}" if roots.empty?

        files = roots.flat_map do |root|
          ParityInputs.closure_paths(root)
        end.uniq.select { |f| File.exist?(f) }
        Expressir::Express::Parser.from_files(files)
      end
    end
  end
end
