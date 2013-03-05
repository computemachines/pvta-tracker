#! /usr/bin/ruby

require 'pp'
require 'ruby-debug'

require_relative 'DataStore'
require_relative 'DataSource'

module PVTA
  class Tracker
    attr_reader :data
    def initialize
      @data = DataStore.new
      @source = DataSource.new

      route_names = ['30', '31', '32', '34', '35', '37', '38', '39', '45', '46', 'B43', 'R41', 'R42', 'R44', 'B48', 'M40']

      initialize_routes(route_names) if @data.Route.count < 16

      initialize_stops() if @data.Stop.count < 363
    end


    def initialize_routes route_names
      @source.log.info('initialize_routes')
      route_names.each_with_index do |route_name, id|
        begin
          route = @data.Route.new(name: route_name)
          route.id = id
          route.save
        rescue
        end
      end
    end

    def initialize_stops
      @source.log.info('initialize_stops')
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

          route.stops << @data.Stop.find(stop.id)
        end
      end
    end

    def update_schedule
      @source.log.info('update_schedule')
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

    def update_all_bus_positions
      @source.log.info('update_bus_positions')
      @data.Route.all.each do |route|
        update_bus_positions route 
      end
    end
    def update_history_with_data busData
      lastHistory = @data.Bus.find(busData[:id]).histories.last
      if [lastHistory.lat, lastHistory.lng] == busData[:position]
        # gps hasn't updated yet, probably
        return false
      else
        history = @data.History.new()
        history.time = busData[:time]
        history.lat = busData[:position][0]
        history.lng = busData[:position][1]
        history.bus_id = busData[:id]
        history.save
        
      end
    end
    def add_bus_if_nonexist busData
      begin
        bus = @data.Bus.find(busData[:id])
      rescue ActiveRecord::RecordNotFound => e
        bus = @data.Bus.new() if @bus.nil?
        bus.id = busData[:id]
        bus.route = @data.Route.where(name: busData[:route]).first
        bus.save
      end
    end
    
    def update_bus_positions 

      busIdDeltas = {} #hash of (range of gps update interval) per bus
      threads = []
      routeQueryTimes = {}

      @data.Route.all.each do |route|
        delay = 1.minute
        threads << Thread.new(route, delay) do
          sleep delay

          unless routeQueryTimes.respond_to? route.name
            routeQueryTimes[route.name] = {}
          end
          routeQueryTimes[route.name] << Time.now

          getBusData(route.name).each do |busData|
            add_bus_if_nonexist busData[:id]
            changed = update_history_with_data busData
            unless busIdDelta.respond_to? :a
              busIdDeltas[busData[:id]] = {
                min: 0, max: Float::INFINITY
              } 
            end
            if changed
              t_n = routeQueryTimes[route.name][-1]
              t_n_minus_2 = routeQueryTimes[route.name][-3]
              busIdDeltas[busData[:id]][:max] = t_n - t_n_minus_2
            end
          end
        end
      end
      
      return busIdDeltas, threads
    end

  end
end
    
