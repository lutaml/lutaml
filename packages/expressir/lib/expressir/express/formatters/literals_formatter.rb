module Expressir
  module Express
    module Formatters
      module LiteralsFormatter
        def self.included(base)
          base.register_formatter Model::Literals::Binary,
                                  :format_literals_binary
          base.register_formatter Model::Literals::Integer,
                                  :format_literals_integer
          base.register_formatter Model::Literals::Logical,
                                  :format_literals_logical
          base.register_formatter Model::Literals::Real, :format_literals_real
          base.register_formatter Model::Literals::String,
                                  :format_literals_string
        end

        def format_literals_binary(node)
          node.value
        end

        def format_literals_integer(node)
          node.value
        end

        def format_literals_logical(node)
          case node.value
          when Model::Literals::Logical::TRUE then "TRUE"
          when Model::Literals::Logical::FALSE then "FALSE"
          when Model::Literals::Logical::UNKNOWN then "UNKNOWN"
          end
        end

        def format_literals_real(node)
          node.value
        end

        def format_literals_string(node)
          if node.encoded
            [
              "\"",
              node.value,
              "\"",
            ].join
          else
            [
              "'",
              node.value,
              "'",
            ].join
          end
        end
      end
    end
  end
end
