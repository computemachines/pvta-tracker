
require 'active_record'
require_relative '../webapp/app/models/route.rb'
require_relative '../webapp/app/models/bus.rb'
require_relative '../webapp/app/models/history.rb'
require_relative '../webapp/app/models/scheduled_stop.rb'

module PVTA
  class DataStore

    ActiveRecord::Base.establish_connection(
                                            :adapter => 'sqlite3',
                                            :database => '../webapp/db/development.sqlite3'
                                            )

    def Route
      Route
    end
    def Bus
      Bus
    end
    def Stop
      Stop
    end
    def ScheduledStop
      ScheduledStop
    end
  end
end
