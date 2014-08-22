module MongoOplogBackup
  class Config
    attr_reader :options

    def initialize(options)
      config_file = options.delete(:file)
      # Command line options take precedence
      @options = from_file(config_file).merge(options) 
    end

    def from_file file
      options = {}
      unless file.nil?
        conf = YAML.load_file(file)
        options[:ssl] = conf["ssl"] unless conf["ssl"].nil?
        options[:host] = conf["host"] unless conf["host"].nil?
        options[:port] = conf["port"].to_s unless conf["port"].nil?
        options[:username] = conf["username"] unless conf["username"].nil?
        options[:password] = conf["password"] unless conf["password"].nil?
      end

      options
    end

    def backup_dir
      options[:dir]
    end

    def command_line_options
      args = []
      args << '--ssl' if options[:ssl]
      [:host, :port, :username, :password].each do |option|
        args += ["--#{option}", options[option].strip] if options[option]
      end

      args += ['--authenticationDatabase', 'admin'] if options[:username]

      args
    end

    def oplog_dump_folder
      File.join(backup_dir, 'dump')
    end

    def oplog_dump
      File.join(oplog_dump_folder, 'local/oplog.rs.bson')
    end

    def state_file
      File.join(backup_dir, 'backup.json')
    end

    def lock_file
      File.join(backup_dir, 'backup.lock')
    end

    def exec(cmd)
      # TODO: filter out password
      MongoOplogBackup.log.debug ">>> #{cmd}"
      p = Process.new(cmd, keep_output: true)
      p.log_output(MongoOplogBackup.log)
      p.run
    end

    def mongodump(*args)
      exec(['mongodump'] + command_line_options + args.flatten)
    end

    def mongo(db, script)
      exec(['mongo'] + command_line_options + ['--quiet', '--norc', script])
    end
  end
end
