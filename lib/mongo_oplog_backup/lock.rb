module MongoOplogBackup
  class LockError < StandardError
  end

  module Lockable
    def self.included(base)
      base.extend(self)
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
