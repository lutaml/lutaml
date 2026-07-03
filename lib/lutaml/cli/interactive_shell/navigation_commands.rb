# frozen_string_literal: true

module Lutaml
  module Cli
    class InteractiveShell
      class NavigationCommands < CommandBase
        def cmd_cd(args)
          if args.empty?
            puts OutputFormatter.warning("Usage: cd PATH")
            return
          end

          path = resolve_path(args[0])
          pkg = repository.find_package(path)

          if pkg
            push_path_history
            self.current_path = path
            puts "Changed to: #{path}"
          else
            puts OutputFormatter.error("Package not found: #{path}")
          end
        end

        def cmd_pwd(_args)
          puts current_path
        end

        def cmd_ls(args)
          path = args.empty? ? current_path : resolve_path(args[0])
          recursive = args.include?("-r") || args.include?("--recursive")

          packages = repository.list_packages(path, recursive: recursive)

          if packages.empty?
            puts OutputFormatter.warning("No packages found at #{path}")
          else
            display_packages(packages)
          end
        end

        def cmd_tree(args)
          path = args.empty? ? current_path : resolve_path(args[0])
          max_depth = extract_depth(args)

          tree_data = repository.package_tree(path, max_depth: max_depth)

          unless tree_data
            puts OutputFormatter.error("Package not found: #{path}")
            return
          end

          puts format_tree(tree_data)
        end

        def cmd_up(_args)
          if current_path == "ModelRoot"
            puts OutputFormatter.warning("Already at root")
            return
          end

          parts = current_path.split("::")
          parts.pop
          new_path = parts.empty? ? "ModelRoot" : parts.join("::")

          push_path_history
          self.current_path = new_path
          puts "Changed to: #{current_path}"
        end

        def cmd_root(_args)
          if current_path == "ModelRoot"
            puts "Already at root"
          else
            push_path_history
            self.current_path = "ModelRoot"
            puts "Changed to: ModelRoot"
          end
        end

        def cmd_back(_args)
          if path_history.size > 1
            path_history.pop
            self.current_path = path_history.last
            puts "Changed to: #{current_path}"
          else
            puts OutputFormatter.warning("No previous location")
          end
        end

        def resolve_path(path)
          return path if path.start_with?("ModelRoot")
          return current_path if path == "."
          return "ModelRoot" if path == "/"
          return resolve_parent_path(path) if path.start_with?("../")
          return resolve_child_path(path) if path.start_with?("./")

          resolve_simple_path(path)
        end

        def resolve_child_path(path)
          "#{current_path}::#{path[2..]}"
        end

        def resolve_simple_path(path)
          current_path == "ModelRoot" ? path : "#{current_path}::#{path}"
        end

        private

        def display_packages(packages)
          packages.each do |pkg|
            icon = config[:icons] ? "#{EnhancedFormatter::ICONS[:package]} " : ""
            puts "#{icon}#{pkg.name}"
          end
          puts ""
          puts "Total: #{packages.size} package(s)"
        end

        def extract_depth(args)
          args.each_with_index do |arg, i|
            return args[i + 1].to_i if arg == "-d" && args[i + 1]
          end
          nil
        end

        def format_tree(tree_data)
          if config[:icons]
            EnhancedFormatter.format_tree_with_icons(tree_data, config)
          else
            OutputFormatter.format_tree(tree_data)
          end
        end

        def resolve_parent_path(path)
          parts = current_path.split("::")
          path.scan("../").each { parts.pop }
          remaining = path.gsub(/^(\.\.\/)+/, "")
          new_path = parts + remaining.split("/")
          new_path.join("::")
        end

        def push_path_history
          return if path_history.last == current_path

          path_history << current_path
        end
      end
    end
  end
end
