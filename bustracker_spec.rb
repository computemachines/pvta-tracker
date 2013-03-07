require './bustracker'

describe 'Bus Tracker' do
  before :all do
    logger = Object.new
    logger.stub :info
    @tracker = PVTA::Tracker.new logger
  end

  it 'should tell if scheduledStop exists' do
    @tracker.scheduledStop_exists?(
      @tracker.data.ScheduledStop.first).should == true
  end

  it 'should get a route by name' do
    @tracker.class.route_from_name('B43').should_not   be(nil)
    @tracker.class.route_from_name('Not Real').should   be(nil)
  end
end
