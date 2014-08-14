require 'mongo_oplog_backup/version'
require 'mongo_oplog_backup/ext/enumerable'
require 'mongo_oplog_backup/ext/timestamp'

require 'mongo_oplog_backup/backup'
require 'mongo_oplog_backup/oplog'

module MongoOplogBackup

  def each_document(filename)
    File.open(filename, 'rb') do |stream|
      while !stream.eof?
        yield BSON::Document.from_bson(stream)
      end
    end
  end
end
