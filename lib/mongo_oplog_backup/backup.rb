require 'json'
require 'fileutils'
require 'mongo_oplog_backup/oplog'

class LockError < StandardError
end

module MongoOplogBackup
  class Backup
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def lock(lockname, &block)
      File.open(lockname, File::RDWR|File::CREAT, 0644) do |file|
        got_lock = file.flock(File::LOCK_EX|File::LOCK_NB)
        if got_lock == false
          raise LockError, "Failed to acquire lock - another backup may be busy"
        end
        yield
      end
    end

    def backup_oplog(options={})
      start_at = options[:start]
      backup = options[:backup]
      raise ArgumentError, ":backup is required" unless backup
      raise ArgumentError, ":start is required" unless start_at

      if start_at
        query = "--query \"{ts : { \\$gte : { \\$timestamp : { t : #{start_at.seconds}, i : #{start_at.increment} } } }}\""
      else
        query = ""
      end
      config.mongodump("--out #{config.oplog_dump_folder} --db local --collection oplog.rs #{query}")

      unless File.exists? config.oplog_dump
        raise "mongodump failed"
      end
      MongoOplogBackup.log.debug "Checking timestamps..."
      timestamps = Oplog.oplog_timestamps(config.oplog_dump)

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
        full_path = File.join(config.backup_dir, backup, outfile)
        FileUtils.mkdir_p File.join(config.backup_dir, backup)
        FileUtils.mv config.oplog_dump, full_path

        result[:file] = full_path
        result[:empty] = false
      end

      FileUtils.rm_r config.oplog_dump_folder rescue nil
      result
    end

    def latest_oplog_timestamp
      script = File.expand_path('../../oplog-last-timestamp.js', File.dirname(__FILE__))
      result_text = config.mongo('local', script)
      begin
        response = JSON.parse(result_text)
        return nil unless response['position']
        BSON::Timestamp.from_json(response['position'])
      rescue JSON::ParserError => e
        raise StandardError, "Failed to connect to MongoDB: #{result_text}"
      end
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

    def perform(mode=:auto, options={})
      if_not_busy = options[:if_not_busy] || false

      perform_oplog_afterwards = false

      lock(config.lock_file) do
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
          MongoOplogBackup.log.info "Performing incremental oplog backup"
          position = BSON::Timestamp.from_json(state['position'])
          result = backup_oplog(start: position, backup: state['backup'])
          unless result[:empty]
            new_entries = result[:entries] - 1
            state['position'] = result[:position]
            File.write(state_file, state.to_json)
            MongoOplogBackup.log.info "Backed up #{new_entries} new entries to #{result[:file]}"
          else
            MongoOplogBackup.log.info "Nothing new to backup"
          end
        elsif mode == :full
          MongoOplogBackup.log.info "Performing full backup"
          result = backup_full
          state = result
          File.write(state_file, state.to_json)
          MongoOplogBackup.log.info "Performed full backup"

          perform_oplog_afterwards = true
        end
      end

      # Has to be outside the lock
      if perform_oplog_afterwards
        # Oplog backup
        perform(:oplog, options)
      end

    rescue LockError => e
      if if_not_busy
        MongoOplogBackup.log.info e.message
        MongoOplogBackup.log.info 'Not performing backup'
      else
        raise
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
