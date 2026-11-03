require "etc"

module Expressir
  module Express
    # Fork-based worker pool for parsing many EXPRESS files in parallel.
    # The native parser holds the GVL for the whole parse, so process-level
    # parallelism is the only way to use multiple cores. Files are
    # independent until reference resolution, which stays in the parent.
    #
    # Unlike sequential parsing, the progress block fires in file order
    # only after all files have been parsed.
    class ParallelFiles
      DEFAULT_MAX_PROCESSES = 4
      FRAME_HEADER_BYTES = 4

      FORK_SUPPORTED = Process.respond_to?(:fork).freeze

      # Forking is never the default: a library must not spawn processes on
      # behalf of its host (forked children inherit broken thread and lock
      # state, and fork does not exist on all Rubies). Parallelism requires
      # an explicit max_processes > 1 from the caller and a platform that
      # supports fork (e.g. not Windows); otherwise the request degrades
      # to sequential parsing.
      def self.sequential?(files, max_processes)
        !FORK_SUPPORTED || max_processes.nil? || max_processes <= 1 ||
          files.size < 3
      end

      # @param files [Array<String>] EXPRESS file paths
      # @param max_processes [Integer, nil] worker cap; nil auto-selects
      # @param parse [Proc] callback taking a file path, returning an ExpFile
      # @param strict [Boolean] re-raise every error, including
      #   Error::SchemaParseFailure, instead of skipping the file
      # @yield [file, exp_file, error] called in original file order
      # @return [Array<Expressir::Model::ExpFile, nil>] parsed files in order;
      #   nil marks a file that failed with Error::SchemaParseFailure
      def self.run(files, parse:, max_processes: nil, strict: false, &block)
        new(files, max_processes, parse, block, strict).run
      end

      def initialize(files, max_processes, parse, block, strict)
        @files = files
        @parse = parse
        @block = block
        @strict = strict
        @worker_count = [
          files.size - 1,
          max_processes || [Etc.nprocessors, DEFAULT_MAX_PROCESSES].min,
        ].min
      end

      def run
        job_pipes = Array.new(@worker_count) { IO.pipe }
        result_pipes = Array.new(@worker_count) { IO.pipe }
        pids = spawn_workers(job_pipes, result_pipes)

        files_results = schedule_jobs(job_pipes, result_pipes)

        ordered_pass(files_results)
      ensure
        cleanup(job_pipes, result_pipes, pids)
      end

      private

      def spawn_workers(job_pipes, result_pipes)
        job_pipes.each_index.map do |i|
          job_r, job_w = job_pipes[i]
          result_r, result_w = result_pipes[i]
          fork do
            job_w.close
            result_r.close
            other_pipes = (job_pipes + result_pipes).flatten -
              [job_r, result_w]
            other_pipes.each { |io| io.close unless io.closed? }
            worker_loop(job_r, result_w)
          end
        end
      end

      # Assigns one job at a time to whichever worker reports a result, so
      # each file is parsed exactly once and each worker holds at most one
      # in-flight job (keeping result pipes free of interleaved frames).
      def schedule_jobs(job_pipes, result_pipes)
        writers = job_pipes.map(&:last)
        readers = result_pipes.map(&:first)
        files_results = Array.new(@files.size)
        next_job = 0
        busy = {}

        writers.each_index do |wi|
          break if next_job == @files.size

          dispatch(writers[wi], next_job)
          busy[wi] = true
          next_job += 1
        end

        until busy.empty?
          ready, = IO.select(readers.values_at(*busy.keys))
          ready.each do |io|
            wi = readers.index(io)
            payload = Marshal.load(read_frame(io)) # rubocop:disable Security/MarshalLoad
            files_results[payload[:index]] = payload

            if next_job < @files.size
              dispatch(writers[wi], next_job)
              next_job += 1
            else
              writers[wi].close unless writers[wi].closed?
              busy.delete(wi)
            end
          end
        end

        files_results
      end

      def dispatch(writer, job_index)
        write_frame(writer, pack_frame(Marshal.dump([job_index, @files[job_index]])))
      end

      def worker_loop(job_r, result_w)
        until job_r.eof?
          data = read_frame(job_r)
          index, file = Marshal.load(data) # rubocop:disable Security/MarshalLoad
          begin
            payload = { index: index, exp_file: @parse.call(file) }
          rescue StandardError => e
            payload = { index: index, error: transferable_error(e) }
          end
          write_frame(result_w, pack_frame(Marshal.dump(payload)))
        end
      rescue Errno::EPIPE
        # parent went away; nothing to report to
        exit!(0)
      end

      # SIGTERM cannot interrupt a worker blocked in the native parser (the
      # GVL is held), so escalate to SIGKILL after a grace period instead of
      # blocking in waitpid forever.
      def cleanup(job_pipes, result_pipes, pids)
        (job_pipes.to_a + result_pipes.to_a).each do |r, w|
          r.close unless r.closed?
          w.close unless w.closed?
        end
        pids.to_a.each { |pid| Process.kill("TERM", pid) if alive?(pid) }

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
        pids.to_a.each do |pid|
          while alive?(pid) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
            Process.waitpid(pid, Process::WNOHANG)
            sleep 0.05
          end
          Process.kill("KILL", pid) if alive?(pid)
          reap(pid)
        end
      end

      def ordered_pass(files_results)
        files_results.each_with_index do |payload, index|
          error = payload[:error]
          @block&.call(@files[index], payload[:exp_file], error)
          raise error if error && (@strict ||
                                  !error.is_a?(Error::SchemaParseFailure))
        end

        files_results.map do |payload|
          payload[:error] ? nil : payload[:exp_file]
        end
      end

      # Errors carrying native-parser state (e.g. Parsanol::ParseFailed with
      # its cause tree) cannot cross a fork boundary; rebuild them without
      # the untransferable internals, preserving class and message.
      def transferable_error(error)
        Marshal.dump(error)
        error
      rescue StandardError
        if error.is_a?(Error::SchemaParseFailure)
          Error::SchemaParseFailure.new(error.filename,
                                        StandardError.new(error.message))
        else
          StandardError.new(error.message)
        end
      end

      def pack_frame(data)
        [data.bytesize].pack("N") + data
      end

      def write_frame(io, frame)
        io.write(frame)
      end

      def read_frame(io)
        header = read_exactly(io, FRAME_HEADER_BYTES)
        read_exactly(io, header.unpack1("N"))
      end

      def read_exactly(io, count)
        data = +""
        while data.bytesize < count
          chunk = io.read(count - data.bytesize)
          unless chunk
            raise Error::ParallelParseError,
                  "worker exited before sending its result"
          end

          data << chunk
        end
        data
      end

      def alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end

      def reap(pid)
        Process.waitpid(pid)
      rescue Errno::ECHILD, Errno::EINVAL
        nil
      end
    end
  end
end
