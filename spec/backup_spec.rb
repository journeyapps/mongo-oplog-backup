require 'spec_helper'
require 'moped'

describe MongoOplogBackup do
  it 'should have a version number' do
    MongoOplogBackup::VERSION.should_not be_nil
  end

  let(:backup) { MongoOplogBackup::Backup.new(MongoOplogBackup::Config.new(dir: 'spec-tmp/backup'), 'backup1') }

  before(:all) do
    # We need one entry in the oplog to start with
    SESSION.with(safe: true) do |session|
      session['test'].insert({a: 1})
    end
  end

  it 'should get the latest oplog entry' do
    ts1 = backup.latest_oplog_timestamp
    ts2 = backup.latest_oplog_timestamp_moped

    ts1.should == ts2
  end

  it 'should error on latest oplog entry with invalid port' do
    b2 = MongoOplogBackup::Backup.new(MongoOplogBackup::Config.new({
      dir: 'spec-tmp/backup', port: '12345'}))
    -> { b2.latest_oplog_timestamp }.should raise_error
  end

  it 'should error on latest oplog entry with invalid password' do
    b2 = MongoOplogBackup::Backup.new(MongoOplogBackup::Config.new({
      dir: 'spec-tmp/backup', username: 'foo', password: '123'}))
    -> { b2.latest_oplog_timestamp }.should raise_error
  end


  it "should perform an oplog backup" do
    first = backup.latest_oplog_timestamp
    first.should_not be_nil
    SESSION.with(safe: true) do |session|
      5.times do
        session['test'].insert({a: 1})
      end
    end
    last = backup.latest_oplog_timestamp
    FileUtils.mkdir_p backup.backup_folder
    backup.write_state({position: first})
    result = backup.backup_oplog(backup: 'backup1')
    result[:entries].should == 6
    result[:empty].should == false
    result[:position].should == last
    result[:first].should == first

    file = result[:file]
    timestamps = MongoOplogBackup::Oplog.oplog_timestamps(file)
    timestamps.count.should == 6
    timestamps.first.should == first
    timestamps.last.should == last
  end
end
