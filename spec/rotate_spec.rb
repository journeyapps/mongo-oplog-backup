require 'spec_helper'
require 'fileutils'
require 'timecop'

describe MongoOplogBackup::Rotate do
  SPEC_TMP='spec-tmp/backup'

  let(:rotate) { MongoOplogBackup::Rotate.new(MongoOplogBackup::Config.new(dir: SPEC_TMP)) }

  before(:each) do
    FileUtils.mkdir_p SPEC_TMP
    FileUtils.cp_r Dir['spec/fixtures/rotation/backup/*'], SPEC_TMP
  end

  context 'with defaults' do
    before do
      Timecop.freeze(Time.utc(2017,9,1,23,0,0))
    end
    after do
      Timecop.return
    end

    # Fixtures created on the 1st at 00:05:00 GMT+2
    # 1498860301:15	2017-06-30 22:05:01 GMT
    # 1501538704:28	2017-07-31 22:05:04 GMT
    # 1504217100:18	2017-08-31 22:05:00 GMT
    it 'excludes the current and previous backup set' do
      filtered_list = rotate.filter_for_deletion(rotate.backup_list)

      backup_dir = Pathname.new(SPEC_TMP)
      expect(filtered_list).to eq([backup_dir.join('backup-1498860301:15')])
    end

    it 'deletes only the correct directory' do
      rotate.perform

      expect( File.exist?(File.join(SPEC_TMP, 'backup-1501538704:28' )) ).to eq(true)
      expect( File.exist?(File.join(SPEC_TMP, 'backup-1504217100:18' )) ).to eq(true)
      expect( File.exist?(File.join(SPEC_TMP, 'backup-1498860301:15' )) ).to eq(false)
    end

  end

  context 'as a dry run' do
    before do
      Timecop.freeze(Time.utc(2017,9,1,23,0,0))
    end
    after do
      Timecop.return
    end

    let(:config) do
      {
        dir: SPEC_TMP,
        dryRun: true
      }
    end
    let(:rotate) { MongoOplogBackup::Rotate.new(MongoOplogBackup::Config.new(config)) }

    it 'does not delete anything.' do
      rotate.perform

      expect( File.exist?(File.join(SPEC_TMP, 'backup-1501538704:28' )) ).to eq(true)
      expect( File.exist?(File.join(SPEC_TMP, 'backup-1504217100:18' )) ).to eq(true)
      expect( File.exist?(File.join(SPEC_TMP, 'backup-1498860301:15' )) ).to eq(true)
    end
  end


end