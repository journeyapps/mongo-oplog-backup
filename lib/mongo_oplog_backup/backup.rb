require 'json'
require 'mongo_oplog_backup/oplog'

module MongoOplogBackup
  class Backup
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def backup_oplog(options={})
      start_at = options[:start]
      backup = options[:backup]

      if start_at
        query = "--query \"{ts : { \\$gte : { \\$timestamp : { t : #{start_at.seconds}, i : #{start_at.increment} } } }}\""
      else
        query = ""
      end
      config.mongodump("--out #{config.oplog_dump_folder} --db local --collection oplog.rs #{query}")

      puts "Checking timestamps..."
      timestamps = []
      Oplog.each_document(config.oplog_dump) do |doc|
        timestamps << doc['ts']
      end

      unless timestamps.increasing?
        raise "Something went wrong - oplog is not ordered."
      end

      first = timestamps[0]
      last = timestamps[-1]

      if first > start_at
        raise "Expected first oplog entry to be #{start_at.inspect} but was #{first.inspect}\n" +
          "The oplog is probably too small.\n" +
          "Increase the oplog size, the start with another full backup."
      elsif first < start_at
        raise "Expected first oplog entry to be #{start_at.inspect} but was #{first.inspect}\n" +
          "Something went wrong in our query."
      end

      result = {
        entries: timestamps.count,
        first: first,
        position: last
      }

      if timestamps.count == 1
        result[:empty] = true
      else
        outfile = "oplog-#{first}-#{last}.bson"
        puts config.exec("mv #{config.oplog_dump} #{File.join(config.backup_dir, backup, outfile)}")

        result[:file] = outfile
        result[:empty] = false
      end

      puts config.exec("rm -r #{config.oplog_dump_folder}")
      result
    end

    def latest_oplog_timestamp
      script = File.expand_path('../../oplog-last-timestamp.js', File.dirname(__FILE__))
      response = JSON.parse(config.mongo('local', script))
      return nil unless response['position']
      BSON::Timestamp.from_json(response['position'])
    end

    def backup_full
      position = latest_oplog_timestamp
      raise "Cannot backup with empty oplog" if position.nil?
      backup_name = "backup-#{position}"
      dump_folder = File.join(config.backup_dir, backup_name, 'dump')
      config.mongodump("--out #{dump_folder}")
      return {
        position: position,
        backup: backup_name
      }
    end

    def perform(mode=:auto)
      state_file = config.state_file
      state = JSON.parse(File.read(state_file)) rescue nil
      state ||= {}
      have_position = (state['position'] && state['backup'])

      if mode == :auto
        if have_position
          mode = :oplog
        else
          mode = :full
        end
      end

      if mode == :oplog
        raise "Unknown backup position - cannot perform oplog backup." unless have_position
        puts "Performing incremental oplog backup"
        position = BSON::Timestamp.from_json(state['position'])
        result = backup_oplog(start: position, backup: state['backup'])
        unless result[:empty]
          new_entries = result[:entries] - 1
          state['position'] = result[:position]
          File.write(state_file, state.to_json)
          puts
          puts "Backed up #{new_entries} new entries"
        else
          puts "Nothing new to backup"
        end
      elsif mode == :full
        puts "Performing full backup"
        result = backup_full
        state = result
        File.write(state_file, state.to_json)
        puts
        puts "Performed full backup"

        # Oplog backup
        perform(:oplog)
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

  end
end
