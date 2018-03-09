require_relative './psm/api_client'

require 'fileutils'

class Plugin < Struct.new(:name, :code, :config)
  PLUGIN_PATH = "/opt/appoptics/opt/psm"

  class Downloader
    def initialize(client_configuration)
      @account_key = client_configuration.fetch("account_key")
      @hostname = client_configuration.fetch("hostname")
    end

    def call
      ensure_directory_exists

      client = ::Psm::ApiClient.new(account_key, hostname)
      response = client.make_request("/api/v2/account/clients/plugins")

      response.each do |p|
        c = Configuration.new(p["meta"]["options"])
        n = "#{normalize_plugin_name(p['name'])}"
        q = Plugin.new(n, p["code"], c)
        q.save
      end
    end

    private

    attr_reader :account_key, :hostname

    def ensure_directory_exists
      unless File.exists?(PLUGIN_PATH)
        FileUtils.mkdir_p(PLUGIN_PATH)
      end
    end

    def normalize_plugin_name(name)
      name.downcase.gsub(/\W/, ' ').split.join(" ").gsub(/\s/, '_')
    end
  end

  class Configuration < Struct.new(:options)
    def to_yaml
      return unless options.any?

      options.inject({}) do |m, (k,v)|
        m[k] = v["value"] || v["default"]
        m
      end.to_yaml
    end
  end

  def save
    %w(save_ruby_code save_configuraton).each do |m|
      method(m).call
    end
  end

  private

  def save_ruby_code
    save_file("#{name}.rb", code)
  end

  def save_configuraton
    save_file("#{name}.yml", config.to_yaml)
  end

  def save_file(name, content)
    File.write("#{PLUGIN_PATH}/#{name}", content)
  end
end
