require 'open3'
require 'io/wait'


module MongoOplogBackup
  class Command
    def self.logger= logger
      @logger = logger
    end

    def self.logger
      @logger
    end

    attr_reader :command
    attr_reader :standard_output
    attr_reader :standard_error
    attr_reader :status

    def self.execute(command, options={})
      Command.new(command, options).run
    end

    # command must be an array containing the command and arguments
    def initialize(command, options={})
      @command = command
      @standard_output = ''
      @standard_error = ''
      @out_blocks = []
      @err_blocks = []

      logger = options[:logger] || Command.logger

      if logger
        log_output(logger)
      end

      on_stdout do |data|
        @standard_output << data
      end
      on_stderr do |data|
        @standard_error << data
      end
    end

    def on_stdout_line &block
      on_stdout(&lines_proc(&block))
    end

    def on_stderr_line &block
      on_stderr(&lines_proc(&block))
    end

    def on_stderr &block
      @err_blocks << block
    end

    def on_stdout &block
      @out_blocks << block
    end

    def log_output(logger)
      on_stdout_line do |line|
        logger.debug(line)
      end
      on_stderr_line do |line|
        logger.error(line)
      end
    end

    def run
      @status = Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
        stdin.close_write
        until all_eof([stdout, stderr])
          read_available_data(stdout) do |data|
            @out_blocks.each do |block|
              block.call(data)
            end
          end
          read_available_data(stderr) do |data|
            @err_blocks.each do |block|
              block.call(data)
            end
          end
          sleep 0.001
        end

        wait_thr.value
      end
      raise!
      self
    end

    def raise!
      unless status.success?
        raise "Command failed with exit code #{status.exitstatus}"
      end
      self
    end

    private
    def lines_proc &block
      # TODO: buffer partial lines
      return Proc.new do |data|
        data.split("\n").each do |line|
          block.call line
        end
      end
    end

    BLOCK_SIZE = 1024

    def read_available_data(io, &block)
      if io.ready?
        data = io.read_nonblock(BLOCK_SIZE)
        block.call data
      end
    end

    def all_eof(files)
      files.find { |f| !f.eof }.nil?
    end
  end
end