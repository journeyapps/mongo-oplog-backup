require 'spec_helper'
require 'fileutils'

describe MongoOplogBackup::Oplog do
  let(:oplog1) { 'spec/fixtures/oplog-1408088734:1-1408088740:1.bson'}
  let(:oplog2) { 'spec/fixtures/oplog-1408088740:1-1408088810:1.bson'}
  let(:oplog3) { 'spec/fixtures/oplog-1408088810:1-1408088928:1.bson'}
  let(:oplog_merged) { 'spec/fixtures/oplog-merged.bson'}

  it 'should extract oplog timestamps' do
    timestamps = MongoOplogBackup::Oplog.oplog_timestamps(oplog1)
    timestamps.should == [
      BSON::Timestamp.new(1408088734, 1),
      BSON::Timestamp.new(1408088738, 1),
      BSON::Timestamp.new(1408088739, 1),
      BSON::Timestamp.new(1408088740, 1)
    ]
  end

  it 'should merge oplogs' do
    merged_out = 'spec-tmp/oplog-merged.bson'
    MongoOplogBackup::Oplog.merge(merged_out, [oplog1, oplog2, oplog3])

    expected_timestamps =
      MongoOplogBackup::Oplog.oplog_timestamps(oplog1) +
      MongoOplogBackup::Oplog.oplog_timestamps(oplog2) +
      MongoOplogBackup::Oplog.oplog_timestamps(oplog3)

    expected_timestamps.uniq!
    expected_timestamps.sort!  # Not sure if uniq! modifies the order

    actual_timestamps = MongoOplogBackup::Oplog.oplog_timestamps(merged_out)
    actual_timestamps.should = expected_timestamps

    merged_out.should be_same_file_as oplog_merged
  end
end
