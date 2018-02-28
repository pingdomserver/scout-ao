require_relative './client'
require_relative './config'
require_relative './plugin'
require_relative './ao/installer'

require 'fileutils'

class Runner
  class NoApiKeyException < StandardError; end;

  SERVER_METRICS_GEM_VERSION = %(1.2.18)
  SCOUT_GEM_VERSION = %(6.4.4)

  class << self
    def run(api_key, options)
      unless api_key
        raise NoApiKeyException, "AppOptics Api key must be provided"
      end

      # Stop scoutd (to release statsd port)
      system "scoutctl stop"

      Ao::Installer.call(api_key) unless options[:skip_agent]

      # Install gems
      unless options[:skip_gems]
        system "gem install ./package/server_metrics-#{SERVER_METRICS_GEM_VERSION}.gem"
        system "gem install ./package/scout-#{SCOUT_GEM_VERSION}.gem"
      end

      # Install snap plugins
      %w(snap-plugin-collector-psm).each do |p|
        FileUtils.cp File.expand_path("../../package/#{p}", __FILE__),
          "/opt/appoptics/bin/#{p}"
      end

      client_configuration = Client.gather_facts
      Plugin::Downloader.new(client_configuration).call unless options[:skip_plugin]
      Configuration.new(client_configuration).call unless options[:skip_config]

      # Fix scout-related permissions
      # (scout-client would be ran under appoptics user/group)
      system "usermod -a -G scoutd appoptics"
      system """chmod g+rw /var/log/scout/scoutd.log && \
          chmod g+w /var/lib/scoutd/"""

      # Restart appoptics agent
      system "service appoptics-snapteld restart"
    end
  end
end
