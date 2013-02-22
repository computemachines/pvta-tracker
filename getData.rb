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

  def post path, data, header=nil
    request Net::HTTP::Post, path, :data => data, :header => header
  end
  def get path, header=nil
    request Net::HTTP::Get, path, :header => header
  end

  def request type, path, extra
    http = Net::HTTP.new(@host, @port)
    request = type.new( path )
    request.set_form_data extra[:data] unless extra[:data].nil?
    request['Cookie'] = @cookie
    unless extra[:header].nil?
      extra[:header].each {|key, value| request[key] = value }
    end
    response = http.request request
    @cookie = extractCookieFrom response if response.key? 'set-cookie'
    response
  end

  def extractCookieFrom response
    response['set-cookie'].split(';')[0]
  end
end

class PVTAHttpCookie < HttpCookie
  def initialize server
    super( server+'.pvta.com', 81 )
    puts mimic_chrome().body
  end
  def mimic_chrome
    headers = {
      'Accept' => '*/*',
      'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.3',
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Host' => 'uts.pvta.com:81',
      'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1312.70 Safari/537.17',
      'Referer' => 'http://uts.pvta.com:81/InfoPoint/'
    }
    get '/InfoPoint/', headers
    get '/InfoPoint/stylesheets/infowindow.css', headers
    get '/InfoPoint/stylesheets/DefaultWithStopID.css', headers
    get '/InfoPoint/WebResource.axd?d=oa08rdorOLwBsdl8cB8ikr0chpve4AgCIl8nkWDrnoGhBQOjbBU11zDtfVu4TuYkzuZfCWji3sBHkgbZ363o53Uuvco1&t=634605330709717464', headers
    get '/InfoPoint/ScriptResource.axd?d=Ct-dmmBe9wImKUOMoqR0korRapwCYtxeRoBeto1kNivXPdvQMz32nZd9cqxK3pF39ASOqh9MCGA_Ksed-OxsE2O8qGeWbKMo9-FdVmH7Wa62dm63XlM6XEnAxscnrxF3Sb7vd2-UTR4VCYaXfpmqYvR7Ie7F50MfOpOB4sy31S2kfLJF0&t=5bd3f947', headers
    get '/InfoPoint/ScriptResource.axd?d=RDvyqpbz2o03WgKett6EJHDf3cszT6t5Scdf24OFsyT2zoLjTfcFG9R8exJz4Z4Em0XFge8fYm595X5sszVTTCqB3ZhSo9ClHb2vC9JxZVy21n5ztZ24q7I1tkosZTtysXmTkebyKLxzs14XYvtzkZ6ZAgMh8tNzpDildkvQOJTRtQ850&t=5bd3f947', headers
    get '/InfoPoint/ScriptResource.axd?d=2A_cCOdha7Xu-UHCBdhoQbs63z9SbjyTC27W-0ggbbj8kx02B8BS-SxxuSkviohl5LNE2iCLLIuf5_e1LYZyf0kjVTIXCHHqFhE20GoKSvhZO5b0HaZxmFL3hkgPRaFRyL2_geehT-QIvNK9Md_4dvDjB10zOfOksOdC2Grg2M58cmvJ0&t=5bd3f947', headers
    get '/InfoPoint/js/avail_ivl.js', headers
    get '/InfoPoint/js/NonMapClicks.js', headers
    get '/InfoPoint/js/stopDepartureWindowControls.js', headers
    get '/InfoPoint/js/clusterMarker.js', headers
    get '/InfoPoint/js/geoxml.js', headers
    get '/InfoPoint/images/CompanyLogo.png', headers
    
    post '/InfoPoint/default.aspx', {
           'ScriptManager1' => 'ScriptManager|messageTimer',
           '__EVENTTARGET' => 'messageTimer',
           '__EVENTARGUMENT' => '',
           '__VIEWSTATE' => '/wEPDwULLTE4MjY1ODc1MTUPZBYCAgMPZBYIAgMPFgweCXN0YXJ0bGF0cAUJNDIuNDMzODE0HglzdGFydGxuZ3AFCi03Mi42Mjk0NDUeCnN0YXJ0em9vbXAFAjEwHhFzaG93TWFwVHlwZUJ1dHRvbgUEdHJ1ZR4Xc21hbGxMYXJnZU5vbmVOYXZCdXR0b24FBXNtYWxsHhF1c2VTdG9wQ2x1c3RlcmluZwUEdHJ1ZWQCBQ8WAh4EaHJlZgUTaHR0cDovL3d3dy5wdnRhLmNvbWQCBw8WBB4JaW5uZXJodG1sZR4FY2xhc3MFGndhcm5pbmdNZXNzYWdlTm90RGlzcGxheWVkZAIZD2QWAmYPZBYCAgcPFgYeCXRpbWVob3VycwUCMTMeC3RpbWVtaW51dGVzBQIzOR4LdGltZXNlY29uZHMFATBkZIwOjceATon18L4/R2geZ8CvCxbz',
           '__ASYNCPOST' => 'true',
           '' => '' }, headers
  end
end

class PVTADataSource
  attr_accessor :uts_http
  def initialize
    @uts_http = PVTAHttpCookie.new 'uts'
    @ntf_http = PVTAHttpCookie.new 'ntf'
  end

  def getStopData id #uses html
    http = @uts_http

    resp = http.get "/InfoPoint/map/GetStopHtml.ashx?stopId=#{id}"
    puts resp.body
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
