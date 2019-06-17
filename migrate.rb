#!/usr/bin/env ruby

require_relative "lib/options"
require_relative "lib/scout/scout"
require_relative "lib/snap/snap"

options = Options.parse(ARGV)

puts "* Deactivate Scout"
Scout.deactivate

puts "* Download PSM plugins"
Scout.download_plugins unless options[:skip_plugins]

puts "* Set permissions"
Scout.fix_permissions

unless options[:skip_config]
  puts "* Stop Snap Agent"
  Snap.stop

  puts "* Configure Snap Agent"
  Snap.reconfigure

  puts "* Start Snap Agent"
  Snap.start
end
