require 'net/http'
require 'json'
require 'uri'

class Plugin < Struct.new(:name, :code, :config)
  def save
  end

  class Downloader
    API_ENDPOINT = %(/api/v2/account/clients/plugins)
    API_HOST = %(http://localhost:3000)

    def initialize(client_configuration)
      @client_key = client_configuration.fetch("account_key")
      @hostname = client_configuration.fetch("hostname")
    end

    def call
      payload = make_request
      payload.each do |p|
        c = Configuration.new(p["meta"]["options"])
        n = p["name"].downcase.gsub(/\s+/, '_')
        q = Plugin.new(n, p["code"], c)
        # q.save
      end
    end

    private

    attr_reader :client_key, :hostname

    def make_request
      uri = URI("#{API_HOST}#{API_ENDPOINT}")
      params = { hostname: hostname, key: client_key }
      uri.query = URI.encode_www_form(params)
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body)
    end
  end

  class Configuration < Struct.new(:options)
  end

  def save(name, options)
  end
end
