require 'pp'
require_relative 'getData'

pvta = PVTADataSource.new
puts pvta.uts_http.cookie
debugger
response = pvta.uts_http.weird_post
puts 'done.'
