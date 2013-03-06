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
require 'logger'

# getScheduleData(stopId) # [{:route, :destination, :edt, :sdt}, ...]
# getRouteData(routeName) # [{:id, :name, :position}, ...]
# getBusData(routeName) # {id: position, ...}
module PVTA
  class DataSource
    attr_accessor :log

    def initialize _log=nil
      @log = _log
      @log = Logger.new STDOUT if @log.nil?
    end

    def getScheduleData(stop)
      ['uts', 'ntf'].map do |s|
        getScheduleDataFromServer(s, stop)
      end.flatten 1
    end

    def getRouteData route
      host = getHostByRoute route
      path = "/InfoPoint/map/GetRouteXml.ashx?RouteId=#{route}"
      log.info("HTTP getRouteData #{route}")
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

    def getBusData route #uses xml
      busPositions = {}
      host = getHostByRoute route
      path = "/InfoPoint/map/GetVehicleXml.ashx?RouteId=#{route}"
      log.info("HTTP getBusData #{route}")
      resp = Net::HTTP.get(URI(host+path))
      vehicles = XmlSimple.xml_in(resp)['vehicle']
      vehicles = [] if vehicles.nil?
      vehicles.each do |bus|
        busPositions[bus["name"].to_i] = 
          [bus['lat'].to_f, bus['lng'].to_f]
      end
      busPositions
    end

    def cookie # invocation is treated as variable lvalue
      return @cookie unless @cookie.nil?
      
      ds = DataStore.new
      log.info('retrieving cookie')
      dbCookie = ds.Cookie.last
      @cookie = {}
      begin
        @cookie = { 'uts' => dbCookie.uts, 'ntf' => dbCookie.ntf }
        getScheduleData 1
      rescue RuntimeError => e
        log.info('Cookie failing, generating new cookie')
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
    
    def getScheduleDataFromServer server, stop
      html = Nokogiri::HTML getScheduleRawHTML server, stop

      departures = html.css('*[class*="DepartureGroup"]')

      departures = departures.map do |departure|
        route, destination, sdt, edt = departure.xpath('./td/text()')

        route = route.to_s
        destination = CGI.unescapeHTML destination.to_s
        sdt, edt = sdt.to_s, edt.to_s
        begin
          sdt = Time.parse sdt
          edt = Time.parse edt
        rescue ArgumentError => e
          {route: route, destination: destination, sdt: sdt, edt: edt}
        end
      end.compact

    end

    def getScheduleRawHTML server, stop
      req = Net::HTTP::Get.new "/InfoPoint/map/GetStopHtml.ashx?stopId=#{stop}"
      req['Referer'] = 'http://uts.pvta.com:81/InfoPoint/'
      req['Cookie'] = "ASP.NET_SessionId=#{cookie[server]}"
      again = true
      while again
        begin
          log.info("HTTP getStopRawHTML #{server}, #{stop}")
          resp = Net::HTTP.start "#{server}.pvta.com", 81 do |http|
            http.request req
          end
          again = false
        rescue
          log.warn("Connection Error")
          sleep 60
        end
      end
      raise "Cookie Expired\n#{resp.body}" if resp.body =~ /Error/
      resp.body
    end

  end
end
