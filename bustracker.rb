#! /usr/bin/ruby

require 'pp'
require 'ruby-debug'

require_relative 'DataStore'
require_relative 'DataSource'

module PVTA
  class Tracker
    attr_reader :data
    def initialize
      routes_names = ['30', '31', '32', '34', '35', '37', '38', '39', '45', '46', 'B43', 'R41', 'R42', 'R44', 'B48', 'M40']

      @data = DataStore.new
      @source = DataSource.new

      routes_names.each_with_index do |route_name, id|
        begin
          route = @data.Route.new(name: route_name)
          route.id = id
          route.save
        rescue
        end
      end

      @data.Route.all.each do |route|
        @source.getRouteData(route.name).each do |stopData|
          stop = @data.Stop.new()
          stop.name = stopData[:name]
          stop.id = stopData[:id]
          stop.lat = stopData[:position][0]
          stop.lng = stopData[:position][1]
          begin
            stop.save
            pp stop
          rescue
          end
        end
      end
      
      @data.Stop.all.each do |stop|
        @source.getStopData(stop.id).each do |sStopData|
          # there are strange references to nonexistant routes
          if not Route.where(name: sStopData[:route]).first.nil?
            sStop = @data.ScheduledStop.new()
            sStop.time = sStopData[:sdt]
            sStop.estimated_time = sStopData[:edt]
            sStop.stop = stop
            sStop.route = Route.where(name: sStopData[:route]).first

            # will only save if not a duplicate
            sStop.save if ScheduledStop.where({
              stop_id: stop.id,
              route_id: Route.where(name: sStopData[:route]).first.id,
              time: sStopData[:sdt]
            }).empty? and sStopData[:sdt] != 'Done'
            sleep 0.1
          else
            puts "Ghost Route: #{stop.name} Route:#{sStopData[:route]}"
          end
        end
      end

    end
  end
end

tracker = PVTA::Tracker.new


