require './DataSource'

describe 'DataSource' do
  before :each do
    logger = Object.new
    logger.stub(:info)
    @source = PVTA::DataSource.new logger
  end

  it 'should cache a working cookie' do
#    PVTA::DataStore.new.Cookie.last.delete
    @source.cookie.should == @source.cookie
  end  

  it 'should return positions during the day' do
    busData = @source.getBusData('35')
    if 6 < Time.now.hour and Time.now.hour < 23
      busData.length.should > 0
    elsif Time.now.hour < 5
      busData.length.should == 0
    end
    busData.class.should == {}.class
  end

  it 'should return scheduleData' do
    data = @source.getScheduleData 68
  end  

end
