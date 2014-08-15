module MongoOplogBackup
  class Config
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def backup_dir
      options[:dir]
    end

    def command_line_options
      ''
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
