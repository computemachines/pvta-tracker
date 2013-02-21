#! /usr/bin/ruby

require 'pp'
require 'nokogiri'
require 'time'
require 'cgi'
require 'ruby-debug'
require 'net/http'

class HttpCookie 
  attr_reader :header, :cookie
  def initialize host, port=80
    @host = host
    @port = port
  end

  def get path
    http = Net::HTTP.new(@host, @port)
    request = Net::HTTP::Get.new( path )
    request['Cookie'] = @cookie
    request['Host'] = 'uts.pvta.com:81'
    request['Referer'] = 'http://uts.pvta.com:81/InfoPoint/'
    request['Accept'] = '*/*'
    response = http.request request
    @cookie = extractCookieFrom response if response.key? 'set-cookie'
    puts '-------- Error --------' if response.code == "500"
    response
  end

  def extractCookieFrom response
    puts '-------- Setting Cookie --------'
    response['set-cookie'].split(';')[0]
  end

end
class PVTAHttpCookie < HttpCookie
  def initialize server
    super( server+'.pvta.com', 81 )
    get '/InfoPoint/'
  end
end

class PVTADataSource
  attr_accessor :uts_http
  def initialize
    @uts_http = PVTAHttpCookie.new 'uts'
#    @ntf_http = PVTAHttpCookie.new 'ntf'
  end

  def getStopData id #uses html
    http = @uts_http

    resp = http.get "/InfoPoint/map/GetStopHtml.ashx?stopId=#{id}"

    html = Nokogiri::HTML(resp.body)
    departures = html.css('*[class*="DepartureGroup"]')
    departures = departures.map do |departure|
      route, destination, sdt, edt = departure.xpath('./td/text()')

      route = route.to_s.to_sym
      destination = CGI.unescapeHTML destination.to_s
      sdt, edt = sdt.to_s, edt.to_s
      begin
        sdt = Time.parse sdt
        edt = Time.parse edt ## might cause bugs
      rescue
      end

      [route, destination, sdt, edt]
    end
  end

  def getBusData route #uses xml
    busPositions = []
    http = route=~/^[A-Z]/ ? @ntf_http : @uts_http
    path = "/InfoPoint/map/GetVehicleXml.ashx?RouteId=#{route}"
    resp = http.get(path)
    vehicles = XmlSimple.xml_in(resp.body)['vehicle']
    vehicles = [] if vehicles.nil?
    vehicles.each do |bus|
      busPositions << {
        route: route.to_s.to_sym, 
        id: bus["name"].to_s.to_sym, 
        position: [bus['lat'].to_f,bus['lng'].to_f]
      }
    end
    busPositions
  end

  def getRouteData route
    http = route=~/^[A-Z]/ ? @ntf_http : @uts_http
    path = "/InfoPoint/map/GetRouteXml.ashx?RouteId=#{route}"
    resp = http.get(path)
    xml = XmlSimple.xml_in(resp.body)
    segments = xml['segments'] # KML of the route
    stops = xml['stops'][0]['stop']

    stops.map do |stop|
      { id: stop['html'].to_i,
        name: stop['label'],
        postion: [stop['lat'].to_f, stop['lng'].to_f] }
    end
  end

end
