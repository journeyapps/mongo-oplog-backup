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
    actual_timestamps.should == expected_timestamps

    merged_out.should be_same_oplog_as oplog_merged
  end

  it 'should parse timestamps from a filename' do
    timestamps = MongoOplogBackup::Oplog.timestamps_from_filename('some/oplog-1408088734:1-1408088740:52.bson')
    timestamps.should == {
      first: BSON::Timestamp.new(1408088734, 1),
      last: BSON::Timestamp.new(1408088740, 52)
    }
  end
  it 'should sort oplogs in a folder' do
    oplogs = MongoOplogBackup::Oplog.find_oplogs('spec/fixtures')
    oplogs.should == [oplog1, oplog2, oplog3]
  end

  it "should merge a backup folder" do
    FileUtils.mkdir_p 'spec-tmp/backup'
    FileUtils.cp_r Dir['spec/fixtures/oplog-*.bson'], 'spec-tmp/backup/'

    MongoOplogBackup::Oplog.merge_backup('spec-tmp/backup')

    'spec-tmp/backup/dump/oplog.bson'.should be_same_oplog_as oplog_merged
  end



  context 'with gzipped oplogs' do
    let(:oplog1) { 'spec/fixtures/gzip/oplog-1479827504:7-1479827518:1.bson.gz'}
    let(:oplog2) { 'spec/fixtures/gzip/oplog-1479827518:1-1479827535:1.bson.gz'}
    let(:oplog3) { 'spec/fixtures/gzip/oplog-1479827535:1-1479828312:1.bson.gz'}
    let(:oplog_merged) { 'spec/fixtures/gzip/oplog-merged-gzipped.bson'}

    it 'should extract oplog timestamps' do
      timestamps = MongoOplogBackup::Oplog.oplog_timestamps(oplog1)
      timestamps.should == [
        BSON::Timestamp.new(1479827504, 7),
        BSON::Timestamp.new(1479827515, 1),
        BSON::Timestamp.new(1479827517, 1),
        BSON::Timestamp.new(1479827518, 1)
      ]
    end

    it 'should merge oplogs' do
      merged_out = 'spec-tmp/oplog-merged-gzipped.bson'
      MongoOplogBackup::Oplog.merge(merged_out, [oplog1, oplog2, oplog3], {gzip: true})

      expected_timestamps =
        MongoOplogBackup::Oplog.oplog_timestamps(oplog1) +
        MongoOplogBackup::Oplog.oplog_timestamps(oplog2) +
        MongoOplogBackup::Oplog.oplog_timestamps(oplog3)

      expected_timestamps.uniq!
      expected_timestamps.sort!  # Not sure if uniq! modifies the order

      actual_timestamps = MongoOplogBackup::Oplog.oplog_timestamps(merged_out)
      actual_timestamps.should == expected_timestamps

      merged_out.should be_same_oplog_as oplog_merged
    end

    it 'should parse timestamps from a filename' do
      timestamps = MongoOplogBackup::Oplog.timestamps_from_filename('some/oplog-1408088734:1-1408088740:52.bson.gz')
      timestamps.should == {
        first: BSON::Timestamp.new(1408088734, 1),
        last: BSON::Timestamp.new(1408088740, 52)
      }
    end

    it "should merge a backup folder" do
      FileUtils.mkdir_p 'spec-tmp/backup-zipped'
      FileUtils.cp_r Dir['spec/fixtures/gzip/oplog-*.bson.gz'], 'spec-tmp/backup-zipped/'

      MongoOplogBackup::Oplog.merge_backup('spec-tmp/backup-zipped')

      'spec-tmp/backup-zipped/dump/oplog.bson'.should be_same_oplog_as oplog_merged
    end
  end
end
