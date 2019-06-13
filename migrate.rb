#!/usr/bin/env ruby

require_relative "lib/options"
require_relative "lib/scout/scout"
require_relative "lib/snap/service"
require_relative "lib/snap/config"

options = Options.parse(ARGV)

puts "* Deactivate Scout"
Scout.deactivate

puts "* Download PSM plugins"
Scout.download_plugins unless options[:skip_plugins]

unless options[:skip_config]
  puts "* Stop Snap Agent"
  SnapService.stop

  puts "* Configure Snap Agent"
  SnapConfig.reconfigure

  puts "* Start Snap Agent"
  SnapService.start
end
