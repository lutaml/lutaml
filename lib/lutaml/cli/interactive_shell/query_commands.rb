# frozen_string_literal: true

module Lutaml
  module Cli
    class InteractiveShell
      class QueryCommands < CommandBase
        def cmd_find(args)
          if args.empty?
            puts OutputFormatter.warning("Usage: find CLASS_NAME")
            return
          end

          query = args.join(" ")
          results = repository.search(query, types: [:class])

          if results[:class].empty?
            puts OutputFormatter.warning("No classes found matching '#{query}'")
          else
            puts OutputFormatter.colorize(
              "Found #{results[:class].size} class(es):", :cyan
            )
            display_class_results(results[:class])
          end
        end

        def cmd_show(args)
          if args.empty?
            puts OutputFormatter.warning(
              "Usage: show class QNAME | show package PATH | show NUMBER",
            )
            return
          end

          subcommand = args[0].downcase

          case subcommand
          when "class"
            show_class(args[1..].join(" "))
          when "package"
            show_package(args[1..].join(" "))
          when /^\d+$/
            show_numbered_result(subcommand.to_i)
          else
            show_class(args.join(" "))
          end
        end

        def cmd_search(args)
          if args.empty?
            puts OutputFormatter.warning("Usage: search QUERY")
            return
          end

          query = args.join(" ")
          results = repository.search(query)

          if results.values.all?(&:empty?)
            puts OutputFormatter.warning("No results found for '#{query}'")
          else
            display_search_results(results)
          end
        end

        def cmd_results(_args)
          if last_results.nil? || last_results.empty?
            puts OutputFormatter.warning("No previous results")
          else
            puts OutputFormatter.colorize(
              "Last results (#{last_results.size}):", :cyan
            )
            last_results.each_with_index do |item, i|
              puts "  #{i + 1}. #{item}"
            end
          end
        end

        def show_class(qname)
          cls = repository.find_class(qname)

          unless cls
            puts OutputFormatter.error("Class not found: #{qname}")
            return
          end

          if config[:icons]
            puts EnhancedFormatter.format_class_details_enhanced(cls)
          else
            display_class_plain(cls, qname)
          end
        end

        def show_package(path)
          nav = shell.navigation
          path = nav.resolve_path(path)
          pkg = repository.find_package(path)

          unless pkg
            puts OutputFormatter.error("Package not found: #{path}")
            return
          end

          display_package_contents(pkg, path)
        end

        def show_numbered_result(number)
          if last_results.nil? || last_results.empty?
            puts OutputFormatter.warning("No previous results")
            return
          end

          index = number - 1
          if index.negative? || index >= last_results.size
            puts OutputFormatter.error("Invalid result number: #{number}")
            return
          end

          show_class(last_results[index])
        end

        def display_search_results(results)
          results.each do |type, items|
            next if items.empty?

            puts ""
            puts OutputFormatter.colorize(
              "#{type.to_s.capitalize} Results (#{items.size}):", :cyan
            )

            case type
            when :class
              display_class_results(items)
            when :attribute
              display_attribute_results(items)
            when :association
              display_association_results(items)
            end
          end
        end

        private

        def display_class_results(items)
          self.last_results = items
          items.each_with_index do |qname, i|
            icon = config[:icons] ? "#{EnhancedFormatter::ICONS[:class]} " : ""
            puts "  #{i + 1}. #{icon}#{qname}"
          end
          puts ""
          puts "Use 'show NUMBER' to view details"
        end

        def display_attribute_results(items)
          items.each do |item|
            puts "  - #{item[:class_name]}::#{item[:attribute_name]} : " \
                 "#{item[:type]}"
          end
        end

        def display_association_results(items)
          items.each do |item|
            icon = config[:icons] ? "#{EnhancedFormatter::ICONS[:association]} " : ""
            puts "  #{icon}#{item[:source]} → #{item[:target]}"
          end
        end

        def display_class_plain(cls, qname)
          puts OutputFormatter.colorize("Class: #{qname}", :cyan)
          puts "=" * 50
          puts ""
          puts "Name: #{cls.name}"

          display_class_attributes(cls) if has_displayable_attributes?(cls)
        end

        def has_displayable_attributes?(cls)
          cls.is_a?(Lutaml::Uml::Classifier) && cls.attributes && !cls.attributes.empty?
        end

        def display_class_attributes(cls)
          puts ""
          puts OutputFormatter.colorize("Attributes:", :yellow)
          cls.attributes.each do |attr|
            puts "  - #{attr.name}: #{attr.type}"
          end
        end

        def display_package_contents(pkg, path)
          puts OutputFormatter.colorize("Package: #{path}", :cyan)
          puts "=" * 50
          puts ""
          puts "Name: #{pkg.name}"
          puts ""

          display_package_classes(path)
        end

        def display_package_classes(path)
          classes = repository.classes_in_package(path)
          puts OutputFormatter.colorize("Classes (#{classes.size}):", :yellow)
          classes.each do |cls|
            icon = config[:icons] ? "#{EnhancedFormatter::ICONS[:class]} " : ""
            puts "  #{icon}#{cls.name}"
          end
        end
      end
    end
  end
end
