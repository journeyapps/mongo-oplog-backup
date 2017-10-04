require 'pathname'

module MongoOplogBackup
  class Rotate
    include Lockable
    attr_reader :config, :backup_list
    DAY = 86400
    RECOVERY_POINT_OBJECTIVE = 32 * DAY # Longest month + 1
    KEEP_MINIMUM_SETS = 2 # Current & Previous

    BACKUP_DIR_NAME_FORMAT = /\Abackup-\d+:\d+\z/

    def initialize(config)
      @config = config
      @dry_run = !!@config.options[:dryRun]
      @backup_list = find_backup_directories
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

    # Lists subdirectories in the backup location that match the backup set naming format and appear to have completed
    # successfully.
    # @return [Array<Pathname>] backup directories.
    def find_backup_directories
      dirs = Pathname.new(@config.backup_dir).children.select(&:directory?)
      dirs = dirs.select { |dir| dir.basename.to_s =~ BACKUP_DIR_NAME_FORMAT }
      dirs = dirs.select { |dir| File.exist?(File.join(dir, 'state.json')) }
      dirs
    end

    # @param [Array<Pathname>] source_list List of Pathnames for the full backup sets in the backup directory.
    # @return [Array<Pathname]
    def filter_for_deletion(source_list)
      source_list = source_list.sort.reverse.drop(KEEP_MINIMUM_SETS) # Keep a minimum number of full backups
      # The most recent dir might not be the active one (eg. if the mongodump fails). Ensure that it is excluded.
      source_list = source_list.reject { |path| path.basename.to_s == current_backup_name }

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
  end
end