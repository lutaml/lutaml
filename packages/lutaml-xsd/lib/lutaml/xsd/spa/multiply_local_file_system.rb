module Lutaml
  module Xsd
    module Spa
      class LocalFileSystem
        attr_accessor :roots, :patterns

        def initialize(roots, patterns = ["_%s.liquid", "%s.liquid"])
          @roots    = roots
          @patterns = patterns
        end

        def read_template_file(template_path)
          full_path = full_path(template_path)

          unless File.exist?(full_path)
            raise FileSystemError, "No such template '#{template_path}'"
          end

          File.read(full_path)
        end

        def full_path(template_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          unless %r{\A[^./][a-zA-Z0-9_/]+\z}.match?(template_path)
            raise ::Liquid::FileSystemError,
                  "Illegal template name '#{template_path}'"
          end

          result_path = if template_path.include?("/")
                          roots
                            .map do |root|
                              patterns.map do |pattern|
                                File.join(
                                  root,
                                  File.dirname(template_path),
                                  pattern % File.basename(template_path),
                                )
                              end
                            end
                            .flatten
                            .find { |path| File.file?(path) }
                        else
                          roots
                            .map do |root|
                              patterns.map do |pattern|
                                File.join(root, pattern % template_path)
                              end
                            end
                            .flatten
                            .find { |path| File.file?(path) }
                        end

          if result_path.nil?
            raise ::Liquid::FileSystemError,
                  "No documents in template path:  " \
                  "#{File.expand_path(template_path)}"
          end

          unless roots.any? do |root|
            File.expand_path(result_path).start_with?(
              File.expand_path(root),
            )
          end
            raise ::Liquid::FileSystemError,
                  "Illegal template path '#{File.expand_path(result_path)}'"
          end

          result_path
        end
      end
    end
  end
end
