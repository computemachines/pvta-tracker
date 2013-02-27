#! /usr/bin/ruby

require 'pp'

require_relative 'DataStore.rb'
require_relative 'DataSource.rb'

module PVTA
  class Tracker
    def initialize
      @routes = ['30', '31', '32', '34', '35', '37', '38', '39', '45', '46', 'B43', 'R41', 'R42', 'R44', 'B48', 'M40']
      puts @routes.count

      @data = DataStore.new

      @routes.each_with_index do |route_name, id|
        begin
          route = @data.Route.new(name: route_name)
          route.id = id
          route.save
        rescue
        end
      end

      puts @data.Route.count
    end
  end
end

PVTA::Tracker.new
