#! /usr/bin/ruby

require 'pp'
require 'time'
require 'cgi'
require 'xmlsimple'
require 'ruby-debug'
require 'net/http'
require 'selenium-webdriver'
require 'nokogiri'
require_relative 'DataStore'

# getStopData   stopId => [{:route, :destination, :edt, :sdt}, ...]
# getRouteData  route => [{:stopId, :name, :position}, ...]
# getBusData    route => [{:route, :busId, :GPS_position}, ...]
module PVTA
  class DataSource
    def cookie # invocation is treated as variable lvalue
      return @cookie unless @cookie.nil?
      
      ds = DataStore.new
      puts 'retrieving cookie'
      dbCookie = ds.Cookie.last
      @cookie = {}
      begin
        @cookie = { 'uts' => dbCookie.uts, 'ntf' => dbCookie.ntf }
        getStopData 1
      rescue
        puts 'Cookie failing, generating new cookie'
        @cookie['uts'] = getPVTACookie 'uts'
        @cookie['ntf'] = getPVTACookie 'ntf'
        ds.Cookie.new(uts: @cookie['uts'], ntf: @cookie['ntf']).save
      end
      return @cookie
    end

    def getHostByRoute route
      if route =~ /^[A-Z]/ 
        'http://ntf.pvta.com:81'
      else
        'http://uts.pvta.com:81'
      end
    end
    
    # sets up the state required to make the html request
    def getPVTACookie server
      driver = Selenium::WebDriver.for :firefox
      driver.get "http://#{server}.pvta.com:81/InfoPoint/"

      driver.find_element(:id, 'NameID_35').click() if server == 'uts'
      driver.find_element(:id, 'BoxID_B43').click() if server == 'ntf'

      cookie = driver.manage.all_cookies[0][:value]
      driver.close
      cookie
    end
    
    def getStopData(stop)
      ['uts', 'ntf'].map do |s|
        getStopDataFromServer(s, stop)
      end.flatten 1
    end

    def getStopDataFromServer server, stop
      html = Nokogiri::HTML getStopRawHTML server, stop

      departures = html.css('*[class*="DepartureGroup"]')
      departures = departures.map do |departure|
        route, destination, sdt, edt = departure.xpath('./td/text()')

        route = route.to_s
        destination = CGI.unescapeHTML destination.to_s
        sdt, edt = sdt.to_s, edt.to_s
        begin; sdt = Time.parse sdt; rescue; end
        begin; edt = Time.parse edt; rescue; end
        
        {route: route, destination: destination, sdt: sdt, edt: edt}
      end
    end

    def getStopRawHTML server, stop
      req = Net::HTTP::Get.new "/InfoPoint/map/GetStopHtml.ashx?stopId=#{stop}"
      req['Referer'] = 'http://uts.pvta.com:81/InfoPoint/'
      req['Cookie'] = "ASP.NET_SessionId=#{cookie[server]}"
      again = true
      while again
        begin
          resp = Net::HTTP.start "#{server}.pvta.com", 81 do |http|
            http.request req
          end
          again = false
        rescue
          puts "---------------- Connection Error ----------------"
          sleep 60
        end
      end
      raise "Cookie Expired\n#{resp.body}" if resp.body =~ /Error/
      resp.body
    end

    def getBusData route #uses xml
      busPositions = []
      host = getHostByRoute route
      path = "/InfoPoint/map/GetVehicleXml.ashx?RouteId=#{route}"
      resp = Net::HTTP.get(URI(host+path))
      vehicles = XmlSimple.xml_in(resp)['vehicle']
      vehicles = [] if vehicles.nil?
      vehicles.each do |bus|
        busPositions << {
          route: route.to_s.to_sym, 
          stopId: bus["name"].to_s.to_sym, 
          position: [bus['lat'].to_f,bus['lng'].to_f]
        }
      end
      busPositions
    end

    def getRouteData route
      host = getHostByRoute route
      path = "/InfoPoint/map/GetRouteXml.ashx?RouteId=#{route}"
      resp = Net::HTTP.get(URI(host+path))
      xml = XmlSimple.xml_in(resp)
      segments = xml['segments'] # KML of the route
      stops = xml['stops'][0]['stop']

      stops.map do |stop|
        { id: stop['html'].to_i,
          name: stop['label'],
          position: [stop['lat'].to_f, stop['lng'].to_f] }
      end
    end
  end
end
