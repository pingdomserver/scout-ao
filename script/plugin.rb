require 'net/http'
require 'json'
require 'uri'

class Plugin < Struct.new(:name, :code, :config)
  def save
  end

  class Downloader
    def initialize(client_configuration)
      @account_key = client_configuration.fetch("account_key")
      @hostname = client_configuration.fetch("hostname")
    end

    def call
      client = Psm::ApiClient.new(account_key, hostname)
      response = client.make_request("/api/v2/account/clients/plugins")

      response.each do |p|
        c = Configuration.new(p["meta"]["options"])
        n = p["name"].downcase.gsub(/\s+/, '_')
        q = Plugin.new(n, p["code"], c)
        # q.save
      end
    end

    private

    attr_reader :account_key, :hostname
  end

  class Configuration < Struct.new(:options)
  end

  def save(name, options)
  end
end
