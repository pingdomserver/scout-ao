#!/usr/bin/env ruby

require_relative "lib/options"
require_relative "lib/scout/scout"
require_relative "lib/snap/service"
require_relative "lib/snap/config"

options = Options.parse(ARGV)

Scout.deactivate

Scout.download_plugins unless options[:skip_plugins]

unless options[:skip_config]
  SnapService.stop
  SnapConfig.reconfigure
  SnapService.start
end
