require 'pathname'

module MongoOplogBackup
  class Rotate
    attr_reader :config, :backup_list
    DAY = 86400
    RECOVERY_POINT_OBJECTIVE = 32 * DAY # Longest month + 1
    KEEP_MINIMUM_SETS = 2 # Current & Previous

    def initialize(config)
      @config = config
      @dry_run = !!@config.options[:dryRun]
      @backup_list = Pathname.new(@config.backup_dir).children.select(&:directory?)
      if @config.options[:keepDays].nil?
        @recovery_point_objective = RECOVERY_POINT_OBJECTIVE
      else
        @recovery_point_objective = @config.options[:keepDays] * DAY
      end

    end

    def current_backup_name
      if @current_backup_name.nil?
        state_file = config.global_state_file
        state = JSON.parse(File.read(state_file)) rescue nil
        state ||= {}
        @current_backup_name = state['backup']
      end
      @current_backup_name
    end

    def perform
      lock(config.global_lock_file) do
        MongoOplogBackup.log.info "Rotating out old backups."

        if @backup_list.count >= 0 && @backup_list.count <= KEEP_MINIMUM_SETS
          MongoOplogBackup.log.info "Too few backup sets to automatically rotate."
        elsif @backup_list.count > KEEP_MINIMUM_SETS
          filter_for_deletion(@backup_list).each do |path|
            MongoOplogBackup.log.info "#{@dry_run ? '[DRYRUN] Would delete' : 'Deleting'} #{path}."
            begin
              FileUtils.remove_entry_secure(path) unless @dry_run
            rescue StandardError => e
              MongoOplogBackup.log.error "Delete failed: #{e.message}"
            end
          end
        end

        MongoOplogBackup.log.info "Rotating out old backups completed."
      end
    end

    # @param [Array<Pathname>] source_list List of Pathnames for the full backup sets in the backup directory.
    # @returns [Array<Pathname]
    def filter_for_deletion(source_list)
      # The most recent dir might not be the active one (eg. if the mongodump fails)
      source_list = source_list.reject { |path| path.basename.to_s == current_backup_name }
      source_list = source_list.sort.reverse.drop(KEEP_MINIMUM_SETS-1) # Exclude the newest dir (which will be the current or previous backup)

      source_list.select {|path| age_of_backup_in_seconds(path.basename) > @recovery_point_objective }
    end

    private

    def age_of_backup_in_seconds(path)
      Time.now.to_i - timestamp_from_string(path.to_s).seconds
    end

    # Accepts: <seconds>[:ordinal]
    def timestamp_from_string(string)
      match = /(\d+)(?::(\d+))?/.match(string)
      return nil unless match
      s1 = match[1].to_i
      i1 = match[2].to_i
      BSON::Timestamp.new(s1,i1)
    end

    def lock(lockname, &block)
      File.open(lockname, File::RDWR|File::CREAT, 0644) do |file|
        # Get a non-blocking lock
        got_lock = file.flock(File::LOCK_EX|File::LOCK_NB)
        if got_lock == false
          raise LockError, "Failed to acquire lock - another backup may be busy"
        end
        yield
      end
    end
  end
end