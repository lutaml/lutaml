require "digest"
require "zlib"

module Expressir
  module Express
    class Cache
      # Format: magic + SHA-256 (raw, 32 bytes) + Zlib-deflated Marshal.dump
      # of Model::Cache. The digest detects corruption; a corrupted cache is
      # disposable — callers drop the file and regenerate. Marshal is only
      # safe for trusted, locally generated cache files.
      MAGIC = "EXPRC1".freeze

      DIGEST_BYTES = Digest::SHA256.digest("").bytesize

      # Save Express model into a cache file
      # @param file [String] cache file path
      # @param content [Model::ModelElement] Express model
      # @param root_path [String] Express repository root path, to be stripped from Express file paths to create a portable cache file
      # @param test_overwrite_version [String] don't use, only for tests
      # @return [nil]
      def self.to_file(file, content, root_path: nil,
test_overwrite_version: nil)
        version = test_overwrite_version || Expressir::Version::VERSION

        cache = Model::Cache.new(
          version: version,
          content: content,
          root_path: root_path,
        )

        data = Zlib::Deflate.deflate(Marshal.dump(cache), 1)
        File.binwrite(file, "#{MAGIC}#{Digest::SHA256.digest(data)}#{data}")

        nil
      end

      # Load Express model from a cache file
      # @param file [String] cache file path
      # @param root_path [String] Express repository root path, to be prepended to Express file paths if loading a portable cache file
      # @param test_overwrite_version [String] don't use, only for tests
      # @return [Model::ModelElement] Express model
      # @raise [Error::CacheCorruptedError] if the file is not a valid cache file or its digest does not match
      # @raise [Error::CacheVersionMismatchError] if the cache was written by another Expressir version
      def self.from_file(file, root_path: nil, test_overwrite_version: nil)
        version = test_overwrite_version || Expressir::Version::VERSION

        raw = File.binread(file)
        data = Zlib::Inflate.inflate(validated_data(raw))
        cache = Marshal.load(data) # rubocop:disable Security/MarshalLoad

        if cache.version != version
          raise Error::CacheVersionMismatchError.new(cache.version, version)
        end

        cache
      rescue TypeError, ArgumentError, RangeError
        raise Error::CacheCorruptedError
      end

      def self.validated_data(raw)
        header = MAGIC.bytesize + DIGEST_BYTES
        unless raw.bytesize > header && raw.start_with?(MAGIC)
          raise Error::CacheCorruptedError
        end

        digest = raw.byteslice(MAGIC.bytesize, DIGEST_BYTES)
        data = raw.byteslice(header, raw.bytesize - header)
        unless Digest::SHA256.digest(data) == digest
          raise Error::CacheCorruptedError
        end

        data
      end
    end
  end
end
