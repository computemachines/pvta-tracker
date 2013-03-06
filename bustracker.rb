#! /usr/bin/ruby

require 'pp'
require 'ruby-debug'
require 'logger'

require_relative 'DataStore'
require_relative 'DataSource'

module PVTA
  class Tracker
    attr_reader :data
    def initialize log=nil
      @log = log
      @log = Logger.new STDOUT if @log.nil?

      @data = DataStore.new
      @source = DataSource.new @log

      route_names = ['30', '31', '32', '34', '35', '37', '38', '39', '45', '46', 'B43', 'R41', 'R42', 'R44', 'B48', 'M40']

      initialize_routes(route_names) if @data.Route.count < 16

      initialize_stops() if @data.Stop.count < 363

      updater = BusPositionUpdater.new @data, @source
      updater.start
    end


    def initialize_routes route_names
      @log.info('initialize_routes')
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

    def scheduledStop_exists? sStop
      not ScheduledStop.where({
        stop_id: sStop.stop_id,
        route_id: sStop.route_id,
        time: sStop.time
      }).empty?
    end
    
    def self.route_from_name name
      Route.where(name: name).first
    end
    
    def self.sStop_from_sStopData sStopData
      sStop = @data.ScheduledStop.new()
      sStop.time = sStopData[:sdt]
      sStop.estimated_time = sStopData[:edt]
      sStop.stop = stop
      sStop.route = route_from_name sStopData[:route]
    end

    def update_schedule
      @log.info('update_schedule')

      @data.Stop.all.each do |stop|
        @source.getStopData(stop.id).each do |sStopData|

          # there are strange references to nonexistant routes in 
          #    some of the scheduled stops

          unless route_from_name(sStopData[:route]).nil?
            sStop = sStop_from_sStopData sStopData
            sStop.save if scheduledStop_exits? sStop
          end

        end
      end
    end

    class BusPositionUpdater
      class Bus
        attr_accessor :min, :max, :queryTimes, :id, :thread
        def initialize id
          @id = id
          @min = 0; @max = Float::INFINITY
          queryTimes = []
          @thread = Thread.new do; end
          @thread.join
        end
      end

      def initialize data, source
        @data = data; @source = source
      end

      def start
        delay = 1.minute # starting delay
        buses = @data.Bus.all.map {|bus| Bus.new bus.id }
        
        while true
          buses.each do |bus| 
            if bus.thread.status == false
              bus.thread = makeThread( bus )
            end
          end
        end
      end

      def computeNewDelay bus
      end

      def makeThread(bus)
        Thread.new(bus, computeNewDelay(bus)) do
          sleep delay

          bus.queryTimes << Time.now
          if update_history_with_data @source.getBusData bus.id
            t_n = bus.queryTimes[-1]
            t_n_minus_2 = bus.queryTimes[-3]
            bus.max = t_n - t_n_minus_2
            Thread.current[:changed] = true
          else
            t_n = bus.queryTimes[-1]
            t_n_minus_1 = bus.queryTimes[-2]
            bus.min = t_n - t_n_minus_1
            Thread.current[:changed] = false
          end
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
          return true
        end
      end
      def bus_exist? busId
        begin
          @data.Bus.find( busId ).empty?
          return true
        rescue ActiveRecord::RecordNotFound => e
          return false
        end
      end

      def add_bus busData
        bus = @data.Bus.new()
        bus.id = busData[:id]
        bus.route = Tracker.route_from_name busData[:route]
        bus.save
      end
    end

  end
end
  
  tracker = PVTA::Tracker.new
