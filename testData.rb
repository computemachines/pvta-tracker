require 'pp'
require_relative 'getData'

pvta = PVTADataSource.new
pp pvta.getStopData 82

