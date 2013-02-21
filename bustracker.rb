#! /usr/bin/ruby

require 'net/http'
require 'pp'
require 'xmlsimple'

require 'active_record'
require_relative '../webapp/____'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => '../webapp/db/development.db'
)

routes = [30, 31, 32, 34, 35, 37, 38, 39, 45, 46, 'B43', 'R41', 'R42', 'R44', 'B48', 'M40']

def getBusPositions routes
  busPositions = []
  routes.each do |route|
    host = 'uts.pvta.com'
    host = 'ntf.pvta.com' if route.class == String
    
    again = true
    while again
      begin
        again = false
        xmlResponse = Net::HTTP.get(host, "/InfoPoint/map/GetVehicleXml.ashx?RouteId=#{route}", port=81)
      rescue
        again = true
        sleep 1
      end
    end

    vehicles = XmlSimple.xml_in(xmlResponse)['vehicle']
    vehicles = [] if vehicles.nil?
    vehicles.each do |bus|
      busPositions << {route: route.to_s, id: bus["name"], position: [bus['lat'].to_f,bus['lng'].to_f]}
    end
   end
  busPositions
end

known_stops = []

old = []
while true
  sleep 1
  new = getBusPositions routes
  new.each do |bus|
    if not known_stops.include? bus[:position]
      known_stops << bus[:position]
      pp bus
    elsif not old.include? bus      
      puts 'repeat stop identified: '
      pp bus
    end
  end
  old = new
end

