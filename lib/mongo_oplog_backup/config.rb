module MongoOplogBackup
  class Config
    def command_line_options
      ''
    end

    def exec(cmd)
      puts ">>> #{cmd}"
      `#{cmd}`
    end

    def mongodump(args)
      puts exec("mongodump #{command_line_options} #{args}")
    end

    def mongo(db, script)
      exec("mongo #{command_line_options} --quiet --norc #{db} #{script}")
    end
  end
end
