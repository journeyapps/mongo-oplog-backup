$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'mongo_oplog_backup'
require 'fileutils'

FileUtils.rm_rf 'test.log'
MongoOplogBackup.log = Logger.new('test.log')

#https://gist.github.com/mattwynne/736421
RSpec::Matchers.define(:be_same_file_as) do |exected_file_path|
  match do |actual_file_path|
    md5_hash(actual_file_path).should == md5_hash(exected_file_path)
  end

  def md5_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
  end
end

RSpec::Matchers.define(:be_same_oplog_as) do |exected_file_path|
  match do |actual_file_path|
    timestamps(actual_file_path).should == timestamps(exected_file_path)
    actual_file_path.should be_same_file_as exected_file_path
  end

  failure_message do |actual_file_path|
    ets = timestamps(exected_file_path).join("\n")
    ats = timestamps(actual_file_path).join("\n")
    "expected that #{actual_file_path} would be the same as #{exected_file_path}\n" +
    "Expected timestamps:\n#{ets}\n" +
    "Actual timestamps:\n#{ats}"
  end

  def timestamps(file_path)
    MongoOplogBackup::Oplog.oplog_timestamps(file_path)
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :should
  end

  config.before(:each) do
    FileUtils.mkdir_p 'spec-tmp'
  end

  config.after(:each) do
    FileUtils.rm_rf 'spec-tmp'
  end
end

require 'moped'
SESSION = Moped::Session.new([ "127.0.0.1:27017" ])
SESSION.use 'backup-test'
