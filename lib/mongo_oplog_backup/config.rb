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
      ssl = options[:ssl] ? '--ssl ' : ''
      host = options[:host] ? "--host #{options[:host].strip} " : ''
      port = options[:port] ? "--port #{options[:port].strip} " : ''
      username = options[:username] ? "--username #{options[:username].strip} " : ''
      password = options[:password] ? "--password #{options[:password].strip} " : ''
      "#{host}#{port}#{ssl}#{username}#{password}"
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
      MongoOplogBackup.log.debug ">>> #{cmd}"
      `#{cmd}`
    end

    def mongodump(args)
      MongoOplogBackup.log.info exec("mongodump #{command_line_options} #{args}")
    end

    def mongo(db, script)
      exec("mongo #{command_line_options} --quiet --norc #{db} #{script}")
    end
  end
end
