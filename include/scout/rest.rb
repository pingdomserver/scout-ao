require 'net/http'
require 'json'
require 'uri'

module PSM
  class APIClient
    class << self
      def development?
        ENV['RACK_ENV'] == 'development'
      end

      def staging?
        ENV['RACK_ENV'] == 'staging'
      end
    end

    API_HOST = if development?
      "http://localhost:3000"
    elsif staging?
      "http://staging.server.pingdom.com"
    else
      "http://server.pingdom.com"
    end

    def initialize(account_key, hostname)
      @auth_params = { hostname: hostname, key: account_key }
    end

    def make_request(endpoint)
      uri = URI("#{API_HOST}#{endpoint}")
      uri.query = URI.encode_www_form(auth_params)
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body)
    end

    private

    attr_reader :auth_params
  end
end
