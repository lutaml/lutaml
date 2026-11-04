# frozen_string_literal: true

module Expressir
  class SchemaManifest < Lutaml::Model::Serializable
    attribute :schemas, "Expressir::SchemaManifestEntry",
              collection: true,
              initialize_empty: true
    attribute :path, :string
    attr_accessor :output_path

    def initialize(**args)
      @path = path_relative_to_absolute(path) if path
      super
    end

    def base_path
      File.dirname(@path)
    end

    yaml do
      map "schemas", with: { from: :schemas_from_yaml, to: :schemas_to_yaml }
    end

    def self.from_file(path)
      from_yaml(File.read(path)).tap do |x|
        x.set_initial_path(path)
      end
    rescue StandardError => e
      raise ManifestValidationError,
            "Invalid schema manifest format: #{e.message}"
    end

    def to_file(to_path = path)
      FileUtils.mkdir_p(File.dirname(to_path))
      File.write(to_path, to_yaml)
    end

    def set_initial_path(new_path)
      @path = path_relative_to_absolute(new_path)
      schemas.each do |schema|
        schema.path = path_relative_to_absolute(schema.path)
        schema.container_path = File.expand_path(@path)
      end
    end

    def schemas_from_yaml(model, value)
      model.schemas = value.map do |k, v|
        SchemaManifestEntry.new(id: k,
                                path: path_relative_to_absolute(v["path"]))
      end
    end

    def schemas_to_yaml(model, doc)
      doc["schemas"] = model.schemas.sort_by(&:id).to_h do |schema|
        # We are outputting the schemas collection file to the directory where
        # the collection config is at (assumed to be Dir.pwd), not to the
        # directory we sourced the manifest from, e.g.
        # documents/iso-10303-41/schemas.yaml.

        # So the schema.container_path = @config.path is not
        # in fact needed, as the files are already absolute. This notion of
        # using @path to create relative paths was misconceived
        [
          schema.id,
          {
            "path" => path_absolute_to_relative(
              schema.path,
              model.output_path || Dir.pwd,
            ),
          },
        ]
      end
    end

    def path_relative_to_absolute(relative_path)
      return relative_path if relative_path.nil? || relative_path.empty?

      eval_path = Pathname.new(relative_path)
      return relative_path if eval_path.absolute?

      # Or based on current working directory?
      return relative_path unless @path

      # ... but if this calculates path, we end up expanding it anyway

      Pathname.new(File.dirname(@path)).join(eval_path).expand_path.to_s
    end

    def path_absolute_to_relative(absolute_path, container_path)
      return absolute_path if absolute_path.nil? || absolute_path.empty?

      container_path ||= @path
      return absolute_path unless container_path
      return absolute_path if container_path.empty?

      p = Pathname.new(container_path)
      container = p.directory? ? p.to_s : p.dirname

      # Check if absolute_path is actually absolute
      abs_pathname = Pathname.new(absolute_path)
      return absolute_path unless abs_pathname.absolute?

      abs_pathname.relative_path_from(container).to_s
    end

    def update_path(new_path)
      if @path.nil?
        @path = new_path
        return @path
      end

      old_base_path = File.dirname(@path)
      new_base_path = File.dirname(new_path)
      update_schema_path(old_base_path, new_base_path)

      @path = new_path
    end

    def concat(another_config)
      unless another_config.is_a?(self.class)
        raise StandardError,
              "Can only concat a SchemaManifest object."
      end

      # We need to update the relative paths when paths exist
      if path && another_config.path && path != another_config.path
        new_config = another_config.dup
        new_config.update_path(path)
      end

      schemas.concat(another_config.schemas)
    end

    def save_to_path(filename)
      new_config = dup.tap do |c|
        c.path = filename
        c.update_path(File.dirname(filename))
        c.output_path = filename
      end

      File.open(filename, "w") do |f|
        puts "Writing #{filename}..."
        f.write(new_config.to_yaml)
        puts "Done."
      end
    end

    def update_schema_path(old_base_path, new_base_path)
      schemas.each do |schema|
        schema_path = Pathname.new(schema.path)
        next if schema_path.absolute?

        schema_path = (Pathname.new(old_base_path) + schema_path).cleanpath
        # This is the new relative schema_path
        schema.path = schema_path.relative_path_from(new_base_path)
      end
    end
  end
end
