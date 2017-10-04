require 'logger'

require 'mongo_oplog_backup/version'
require 'mongo_oplog_backup/ext/enumerable'
require 'mongo_oplog_backup/ext/timestamp'

require 'mongo_oplog_backup/lock'
require 'mongo_oplog_backup/command'
require 'mongo_oplog_backup/config'
require 'mongo_oplog_backup/backup'
require 'mongo_oplog_backup/oplog'
require 'mongo_oplog_backup/restore'
require 'mongo_oplog_backup/rotate'

module MongoOplogBackup
  def self.log
    @@log
  end

  def self.log= log
    @@log = log
    Command.logger = log
  end

  MongoOplogBackup.log = Logger.new STDOUT
end
