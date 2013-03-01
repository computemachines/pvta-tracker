
require 'active_record'
require_relative '../webapp/app/models/route'
require_relative '../webapp/app/models/bus'
require_relative '../webapp/app/models/history'
require_relative '../webapp/app/models/scheduled_stop'
require_relative '../webapp/app/models/stop'
require_relative '../webapp/app/models/cookie'

module PVTA
  class DataStore

    ActiveRecord::Base.establish_connection(
                                            :adapter => 'sqlite3',
                                            :database => '../webapp/db/development.sqlite3'
                                            )
    def Cookie
      Cookie
    end
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
    def History
      History
    end
  end
end
