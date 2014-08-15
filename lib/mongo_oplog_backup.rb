require 'logger'

require 'mongo_oplog_backup/version'
require 'mongo_oplog_backup/ext/enumerable'
require 'mongo_oplog_backup/ext/timestamp'

require 'mongo_oplog_backup/config'
require 'mongo_oplog_backup/backup'
require 'mongo_oplog_backup/oplog'

module MongoOplogBackup
  def self.log
    @@log
  end

  def self.log= log
    @@log = log
  end

  @@log = Logger.new STDOUT
end
