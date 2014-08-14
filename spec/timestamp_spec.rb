require 'spec_helper'

describe MongoOplogBackup::Ext::Timestamp do
  it 'should be comparable' do
    a = BSON::Timestamp.new(1408004593, 1)
    b = BSON::Timestamp.new(1408004593, 2)
    c = BSON::Timestamp.new(1408004594, 1)
    (a <=> a).should == 0
    (b <=> b).should == 0
    (a <=> b).should == -1
    (b <=> a).should == 1
    (b <=> c).should == -1
    (a <=> c).should == -1
    (c <=> a).should == 1
  end

  it 'should define from_json' do
    json = {"t" => 1408004593, "i" => 20}
    ts = BSON::Timestamp.from_json(json)
    ts.seconds.should == 1408004593
    ts.increment.should == 20
    ts.as_json.should == json
  end

  it 'should define to_s' do
    ts = BSON::Timestamp.new(1408004593, 2)
    ts.to_s.should == '1408004593:2'
    "#{ts}".should == '1408004593:2'
  end
end
