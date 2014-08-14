require 'spec_helper'

describe Enumerable do
  it 'should define sorted?' do
    [1, 2, 3, 4, 6].sorted?.should == true
    [1, 2, 3, 6, 4].sorted?.should == false
    [1, 2, 3, 4, 4].sorted?.should == true
    [6, 4, 3, 2, 1].sorted?.should == false
    [1].sorted?.should == true
    [].sorted?.should == true
  end

  it 'should define increasing?' do
    [1, 2, 3, 4, 6].increasing?.should == true
    [1, 2, 3, 6, 4].increasing?.should == false
    [1, 2, 3, 4, 4].increasing?.should == false
    [6, 4, 3, 2, 1].increasing?.should == false
    [1].increasing?.should == true
    [].increasing?.should == true
  end
end
