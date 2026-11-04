module Expressir
  module Commands
    class Format < Base
      def run(path)
        repository = Expressir::Express::Parser.from_file(path)

        profile = options[:profile] || "iso"

        case profile.downcase
        when "elf"
          format_with_elf_profile(repository)
        when "iso"
          format_with_iso_profile(repository)
        else
          raise Expressir::InvalidOptionError.new(
            "profile",
            profile,
            valid_options: ["iso", "elf"],
          )
        end
      end

      private

      def format_with_elf_profile(repository)
        formatter_options = {
          indent: options[:indent] || 4,
          provenance: options.fetch(:provenance, true),
        }

        formatter = Expressir::Express::PrettyFormatter.new(formatter_options)
        say formatter.format(repository)
      end

      def format_with_iso_profile(repository)
        repository.schemas.each do |schema|
          say "\n(* Expressir formatted schema: #{schema.id} *)\n"
          say schema.format(no_remarks: true)
        end
      end
    end
  end
end
