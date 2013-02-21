require 'pp'
require_relative 'getData'

pvta = PVTADataSource.new
puts pvta.uts_http.cookie
