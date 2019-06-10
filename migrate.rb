#!/usr/bin/env ruby

require_relative "include/options"
require_relative "include/scout/scout"
require_relative "include/snap/service"
require_relative "include/snap/config"

options = Options.parse(ARGV)

Scout.deactivate

Scout.download_plugins unless options[:skip_plugins]

unless options[:skip_config]
	SnapService.stop
	SnapConfig.reconfigure
	SnapService.start
end
