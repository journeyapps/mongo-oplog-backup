require 'spec_helper'

describe MongoOplogBackup::Command do
  it 'should get stdout' do
    result = MongoOplogBackup::Command.execute(['echo', 'something'])
    result.standard_output.should == "something\n"
    result.standard_error.should == ""
    result.status.exitstatus.should == 0
  end

  it 'should get stderr' do
    result = MongoOplogBackup::Command.execute(['ruby', '-e', '$stderr.puts "FOO"'])
    result.standard_output.should == ""
    result.standard_error.should == "FOO\n"
    result.status.exitstatus.should == 0
  end

  it 'should raise on a non-zero exit code' do
    command = MongoOplogBackup::Command.new(['ruby', '-e', 'exit 123'])
    -> { command.run }.should raise_error
    command.status.exitstatus.should == 123
  end

  it 'should log' do
    io = StringIO.new
    logger = Logger.new io
    MongoOplogBackup::Command.execute(['ruby', '-e', 'puts "BAR"; $stdout.flush; $stderr.puts "FOO"'], logger: logger)
    io.rewind
    log = io.read
    log.should =~ /D, \[.+\] DEBUG -- : BAR\nE, \[.+\] ERROR -- : FOO\n/
  end

end
