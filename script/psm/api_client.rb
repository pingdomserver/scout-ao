module Psm
  class ApiClient
    class << self
      def production?
        ENV['RACK_ENV'] == 'production'
      end

      def staging?
        ENV['RACK_ENV'] == 'staging'
      end
    end

    API_HOST = if production?
      "http://server.pingdom.com"
    elsif staging?
      "http://staging.server.pingdom.com"
    else
      "http://localhost:3000"
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
