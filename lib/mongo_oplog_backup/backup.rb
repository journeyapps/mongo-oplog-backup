module MongoOplogBackup
  class Backup
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def backup_oplog(options={})
      start_at = options[:start]
      if start_at
        query = "--query \"{ts : { \\$gte : { \\$timestamp : { t : #{start_at.seconds}, i : #{start_at.increment} } } }}\""
      else
        query = ""
      end
      config.mongodump("--out backup-tmp --db local --collection oplog.rs #{query}")

      timestamps = []
      each_document('backup-tmp/local/oplog.rs.bson') do |doc|
        timestamps << doc['ts']
      end

      unless timestamps.sorted?
        raise "Oplog is not sorted"
      end

      first = timestamps[0]
      last = timestamps[-1]

      if first != start_at
        raise "Expected first oplog entry to be #{start_at.inspect} but was #{first.inspect}"
      end

      result = {
        entries: timestamps.count,
        first: first,
        position: last
      }

      if timestamps.count == 1
        puts config.exec("rm backup-tmp/local/oplog.rs.bson")
        result[:empty] = true
        return result
      else
        outfile = "oplog-#{first.seconds}:#{first.increment}-#{last.seconds}:#{last.increment}.bson"
        puts config.exec("mv backup-tmp/local/oplog.rs.bson #{outfile}")

        result[:file] = outfile
        result[:empty] = false
        return result
      end
    end

    def latest_oplog_timestamp_moped
      # Alternative implementation for `latest_oplog_timestamp`
      require 'moped'
      session = Moped::Session.new([ "127.0.0.1:27017" ])
      session.use 'local'
      oplog = session['oplog.rs']
      entry = oplog.find.limit(1).sort('$natural' => -1).one
      if entry
        entry['ts']
      else
        nil
      end
    end

    def latest_oplog_timestamp
      script = File.expand_path('../../oplog-last-timestamp.js', File.dirname(__FILE__))
      response = JSON.parse(config.mongo('local', script))
      response['position']
    end

    def backup_full
      position = latest_oplog_timestamp
      config.mongodump('--out backup-full')
      return {
        position: position
      }
    end

    def backup_next
      state_file = 'state.json'
      state = JSON.parse(File.read(state_file)) rescue nil

      if state && state['position']
        puts "Performing incremental oplog backup"
        position = BSON::Timestamp.new(state['position']['t'], state['position']['i'])
        result = backup_oplog(start: position)
        unless result[:empty]
          new_entries = result[:entries] - 1
          state = {
            'position' => result[:position]
          }
          File.write(state_file, state.to_json)
          puts
          puts "Backed up #{new_entries} new entries"
        else
          puts "Nothing new to backup"
        end
      else
        puts "Performing full backup"
        result = backup_full
        state = {
          'position' => result[:position]
        }
        File.write(state_file, state.to_json)
        puts
        puts "Performed full backup"
        backup_next
      end
    end

  end
end
