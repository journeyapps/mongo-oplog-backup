require 'json'
require 'fileutils'
require 'mongo_oplog_backup/oplog'

module MongoOplogBackup
  class Backup
    include Lockable
    attr_reader :config, :backup_name

    def backup_folder
      return nil unless backup_name
      File.join(config.backup_dir, backup_name)
    end

    def state_file
      File.join(backup_folder, 'state.json')
    end

    def initialize(config, backup_name=nil)
      @config = config
      @backup_name = backup_name
      if backup_name.nil?
        state_file = config.global_state_file
        state = JSON.parse(File.read(state_file)) rescue nil
        state ||= {}
        @backup_name = state['backup']
      end
    end

    def write_state(state)
      File.write(state_file, state.to_json)
    end

    def backup_oplog(options={})
      raise ArgumentError, "No state in #{backup_name}" unless File.exists? state_file

      backup_state = JSON.parse(File.read(state_file))
      start_at = options[:start] || BSON::Timestamp.from_json(backup_state['position'])
      raise ArgumentError, ":start is required" unless start_at

      query = ['--query', "{ts : { $gte : { $timestamp : { t : #{start_at.seconds}, i : #{start_at.increment} } } }}"]

      dump_args = ['--out', config.oplog_dump_folder, '--db', 'local', '--collection', 'oplog.rs']
      dump_args += query
      dump_args << '--gzip' if config.use_compression?
      config.mongodump(dump_args)

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
        outfile += '.gz' if config.use_compression?
        full_path = File.join(backup_folder, outfile)
        FileUtils.mkdir_p backup_folder
        FileUtils.mv config.oplog_dump, full_path

        write_state({
          'position' => result[:position]
        })
        result[:file] = full_path
        result[:empty] = false
      end

      FileUtils.rm_r config.oplog_dump_folder rescue nil
      result
    end

    # Because https://jira.mongodb.org/browse/SERVER-18643
    # Mongo shell warns (in stdout) about self-signed certs, regardless of 'allowInvalidCertificates' option.
    def strip_warnings_which_should_be_in_stderr_anyway data
      data.gsub(/^.*[thread\d.*].* certificate.*$/,'')
    end

    def latest_oplog_timestamp
      script = File.expand_path('../../oplog-last-timestamp.js', File.dirname(__FILE__))
      result_text = config.mongo('admin', script).standard_output
      begin
        response = JSON.parse(strip_warnings_which_should_be_in_stderr_anyway(result_text))
        return nil unless response['position']
        BSON::Timestamp.from_json(response['position'])
      rescue JSON::ParserError => e
        raise StandardError, "Failed to connect to MongoDB: #{result_text}"
      end
    end

    def backup_full
      position = latest_oplog_timestamp
      raise "Cannot backup with empty oplog" if position.nil?
      @backup_name = "backup-#{position}"
      if File.exists? backup_folder
        raise "Backup folder '#{backup_folder}' already exists; not performing backup."
      end
      dump_folder = File.join(backup_folder, 'dump')
      dump_args = ['--out', dump_folder]
      dump_args << '--gzip' if config.use_compression?
      result = config.mongodump(dump_args)
      unless File.directory? dump_folder
        MongoOplogBackup.log.error 'Backup folder does not exist'
        raise 'Full backup failed'
      end

      File.write(File.join(dump_folder, 'debug.log'), result.standard_output)

      unless result.standard_error.length == 0
        File.write(File.join(dump_folder, 'error.log'), result.standard_error)
      end

      write_state({
        'position' => position
      })

      return {
        position: position,
        backup: backup_name
      }
    end

    def perform(mode=:auto, options={})
      FileUtils.mkdir_p config.backup_dir
      have_backup = backup_folder != nil

      if mode == :auto
        if have_backup
          mode = :oplog
        else
          mode = :full
        end
      end

      if mode == :oplog
        raise "Unknown backup position - cannot perform oplog backup. Have you completed a full backup?" unless have_backup
        MongoOplogBackup.log.info "Performing incremental oplog backup"
        lock(File.join(backup_folder, 'backup.lock')) do
          result = backup_oplog
          unless result[:empty]
            new_entries = result[:entries] - 1
            MongoOplogBackup.log.info "Backed up #{new_entries} new entries to #{result[:file]}"
          else
            MongoOplogBackup.log.info "Nothing new to backup"
          end
        end
      elsif mode == :full
        lock(config.global_lock_file) do
          MongoOplogBackup.log.info "Performing full backup"
          result = backup_full
          File.write(config.global_state_file, {
            'backup' => result[:backup]
          }.to_json)
          MongoOplogBackup.log.info "Performed full backup"
        end
        perform(:oplog, options)
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
