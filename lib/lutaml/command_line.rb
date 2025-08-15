require "optparse"
require "pathname"
require "lutaml/formatter"
require "lutaml/uml/has_attributes"
require "lutaml/uml/parsers/attribute"
require "lutaml/uml/parsers/dsl"
require "lutaml/uml/parsers/yaml"

module Lutaml
  class CommandLine
    class Error < StandardError; end
    class FileError < Error; end
    class NotSupportedInputFormat < Error; end

    include ::Lutaml::Uml::HasAttributes

    SUPPORTED_FORMATS = %w[yaml lutaml exp].freeze
    DEFAULT_INPUT_FORMAT = "lutaml".freeze

    def self.run(args, out_object, attributes = {})
      new(attributes, out_object).run(args)
    end

    def initialize(attributes = {}, out_object = $stdout)
      @formatter = ::Lutaml::Formatter::Graphviz.new
      @verbose = false
      @option_parser = OptionParser.new
      @out_object = out_object

      setup_parser_options

      # rubocop:disable Rails/ActiveRecordAliases
      update_attributes(attributes)
      # rubocop:enable Rails/ActiveRecordAliases
    end

    def output_path=(value)
      @output_path = determine_output_path_value(value)
    end

    def determine_output_path_value(value)
      unless value.nil? || @output_path = value.is_a?(Pathname)
        return Pathname.new(value.to_s)
      end

      value
    end

    def paths=(values)
      @paths = values.to_a.map { |path| Pathname.new(path) }
    end

    def formatter=(value)
      value = value.to_s.strip.downcase.to_sym
      value = Lutaml::Formatter.find_by(name: value)
      raise Error, "Formatter not found: #{value}" if value.nil?

      @formatter = value
    end

    def input_format=(value)
      if value.nil?
        @input_format = DEFAULT_INPUT_FORMAT
        return
      end

      @input_format = SUPPORTED_FORMATS.detect { |n| n == value }
      raise(NotSupportedInputFormat, value) if @input_format.nil?
    end

    def run(original_args) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      args = original_args.dup
      if args.empty? || args.first.strip == "help"
        print_help
        exit
      end
      begin
        @option_parser.parse!(args)
      rescue StandardError
        nil
      end
      @paths = args
      @formatter.type = @type

      if @output_path&.file? && @paths.length > 1
        raise Error,
              'Output path must be a directory \
              if multiple input files are given'
      end

      @paths.each do |input_path_string|
        input_path = Pathname.new(input_path_string)
        unless input_path.exist?
          raise FileError, "File does not exist: #{input_path}"
        end

        document = Lutaml::Parser
          .parse_into_document(File.new(input_path), @input_format)
          .first
        result = @formatter.format(document)

        if @output_path
          output_path = @output_path
          if output_path.directory?
            output_path = output_path.join(input_path
                                            .basename(".*").to_s +
                                          ".#{@formatter.type}")
          end

          output_path.open("w+") { |file| file.write(result) }
        else
          @out_object.puts(result)
        end
      end
    end

    protected

    def text_bold(body = nil)
      text_effect(1, body)
    end

    def text_italic(body = nil)
      text_effect(3, body)
    end

    def text_bold_italic(body = nil)
      text_bold(text_italic(body))
    end

    def text_underline(body = nil)
      text_effect(4, body)
    end

    def text_effect(num, body = nil)
      result = "\e[#{num}m"
      result << "#{body}#{text_reset}" unless body.nil?

      result
    end

    def text_reset
      "\e[0m"
    end

    def setup_parser_options # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      @option_parser.banner = ""
      format_desc = "The output formatter (Default: '#{@formatter.name}')"
      @option_parser
        .on("-f",
            "--formatter VALUE",
            format_desc) do |value|
        @formatter = value
      end
      @option_parser
        .on("-t", "--type VALUE", "The output format type") do |value|
          @type = value
        end
      @option_parser
        .on("-o", "--output VALUE", "The output path") do |value|
          @output_path = Pathname.new(value)
        end
      @option_parser
        .on("-i", "--input-format VALUE", "The input format") do |value|
          @input_format = value
        end
      @option_parser
        .on("-h", "--help", "Prints this help") do
        print_help
        exit
      end
      @option_parser.on("-g", "--graph VALUE") do |value|
        Parsers::Attribute.parse(value).each do |key, attr_value|
          @formatter.graph[key] = attr_value
        end
      end

      @option_parser.on("-e", "--edge VALUE") do |value|
        Parsers::Attribute.parse(value).each do |key, attr_value|
          @formatter.edge[key] = attr_value
        end
      end

      @option_parser.on("-n", "--node VALUE") do |value|
        Parsers::Attribute.parse(value).each do |key, attr_value|
          @formatter.node[key] = attr_value
        end
      end

      @option_parser.on("-a", "--all VALUE") do |value|
        Parsers::Attribute.parse(value).each do |key, attr_value|
          @formatter.graph[key] = attr_value
          @formatter.edge[key] = attr_value
          @formatter.node[key] = attr_value
        end
      end
    end

    def print_help # rubocop:disable Metrics/AbcSize
      @out_object.puts <<~HELP
        #{text_bold('Usage:')} lutaml [options] PATHS

        #{text_bold('Overview:')} Generate output from Supplied language files if supported

        #{text_bold('Options:')}
        #{@option_parser}
        #{text_bold('Paths:')}

            LUTAML can accept multiple paths for parsing for easier batch processing.

            The location of the output by default is standard output.

            The output can be directed to a path with #{text_bold_italic('--output')}, which can be a file or a directory.
            If the output path is a directory, then the filename will be the same as the input filename,
              with it's file extension substituted with the #{text_bold_italic('--type')}.

            #{text_underline('Examples')}

                `lutaml project.lutaml`

                    Produces DOT notation, sent to standard output

                `lutaml -o . project.lutaml`

                    Produces DOT notation, written to #{text_italic('./project.dot')}

                `lutaml -o ./diagram.dot project.lutaml`

                    Produces DOT notation, written to #{text_italic('./diagram.dot')}

                `lutaml -o ./diagram.png project.lutaml`

                    Produces PNG image, written to #{text_italic('./diagram.png')}

                `lutaml -t png -o . project.lutaml`

                    Produces PNG image, written to #{text_italic('./project.png')}

                `lutaml -t png -o . project.lutaml core_ext.lutaml`

                    Produces PNG images, written to #{text_italic('./project.png')} and #{text_italic('./core_ext.png')}

        #{text_bold('Inputs:')}

            #{text_underline('Lutaml')}

              Lutaml dsl syntax files, supports diagram generation(image or dot files) with Graphviz

        #{text_bold('Formatters:')}

            #{text_underline('Graphviz')}

              Generates DOT notation and can use the DOT notation to generate any format Graphviz can produce.

              The output format is based on #{text_bold_italic('--type')}, which by default is "dot".
              If #{text_bold_italic('--type')} is not given and #{text_bold_italic('--output')} is, the file extension of the #{text_bold_italic('--output')} path will be used.

              Valid types/extensions are: #{Lutaml::Formatter::Graphviz::VALID_TYPES.join(', ')}

              #{text_bold('Options:')}

                  -g, --graph VALUE                The graph attributes
                  -e, --edge VALUE                 The edge attributes
                  -n, --node VALUE                 The node attributes
                  -a, --all VALUE                  Set attributes for graph, edge, and node

      HELP
    end
  end
end
