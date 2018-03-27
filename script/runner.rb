require_relative './client'
require_relative './config'
require_relative './plugin'
require_relative './ao/installer'

require 'fileutils'

class Runner
  class NoApiKeyException < StandardError; end;

  SERVER_METRICS_GEM_VERSION = %(1.2.18)
  SCOUT_GEM_VERSION = %(6.4.8)

  class << self
    def run(api_key, options)
      if !api_key && require_ao_key?(options)
        raise NoApiKeyException, "AppOptics Api key must be provided"
      end

      # Stop scoutd (to release statsd port)
      system "scoutctl stop"
      # Stop Appoptics
      system "service appoptics-snapteld stop"

      Ao::Installer.call(api_key, options) unless options[:skip_agent]

      # Install gems
      unless options[:skip_gems]
        ["server_metrics-#{SERVER_METRICS_GEM_VERSION}.gem", "scout-#{SCOUT_GEM_VERSION}.gem"].each do |gem|
          gem_path = File.expand_path("../../package/#{gem}", __FILE__)
          system "gem install #{gem_path}"
        end
      end

      client_configuration = Client.gather_facts
      client_configuration.merge!({ ao_token: api_key })
      Plugin::Downloader.new(client_configuration).call unless options[:skip_plugin]
      Configuration.new(client_configuration).call(options) unless options[:skip_config]

      # Fix scout-related permissions
      # (scout-client would be ran under appoptics user/group)
      system "usermod -a -G scoutd appoptics"
      system """chmod g+rw /var/log/scout/scoutd.log && \
          chmod g+w /var/lib/scoutd/"""

      # Restart appoptics agent
      system "service appoptics-snapteld restart"

      puts "\nOk."
    end

    def require_ao_key?(options)
      !options[:skip_agent] || !options[:skip_ao_config]
    end
  end
  private_class_method :require_ao_key?
end
