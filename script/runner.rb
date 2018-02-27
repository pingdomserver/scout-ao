require_relative './client'
require_relative './config'
require_relative './plugin'
require_relative './ao/installer'

require 'fileutils'

class Runner
  class NoApiKeyException < StandardError; end;

  class << self
    def run(api_key, options)
      # TODO: API call to AO to enable psm snap plugin

      unless api_key
        raise NoApiKeyException, "AppOptics Api key must be provided"
      end

      Ao::Installer.call(api_key) unless options[:skip_agent]
      client_configuration = Client.gather_facts
      Plugin::Downloader.new(client_configuration).call unless options[:skip_plugin]
      Configuration.new(client_configuration).call unless options[:skip_config]

      # Install gems

      # Install snap plugins

      %w(snap-plugin-collector-psm).each do |p|
        FileUtils.cp File.expand_path("../../package/#{p}", __FILE__),
          "/opt/appoptics/bin/#{p}"
      end

      # Restart appoptics agent

      system "service appoptics-snapteld restart"
    end
  end
end
