require "yaml"
require "net/http"
require "json"
require "uri"

class PSMClient
  def initialize(account_key, hostname)
    @account_key = account_key
    @hostname = hostname
  end

  def roles
    @roles ||= fetch_roles
  end

  def environment
    @environment ||= fetch_environment
  end

  def plugins
    @plugins ||= fetch_plugins
  end

  private

  attr_reader :account_key, :hostname

  def fetch_roles
    @client ||= APIClient.new(account_key, hostname)
    response = @client.make_request("#{APIClient::API_PATH}/roles")
    response.reject! { |r| r["name"] == "All Servers" }
    response.map! { |r| r["name"].gsub(/(\s+|\W+)/, "_") }

    response
  end

  def fetch_environment
    @client ||= APIClient.new(account_key, hostname)
    response = @client.make_request("#{APIClient::API_PATH}/environment")

    response["name"]
  end

  def fetch_plugins
    @client ||= APIClient.new(account_key, hostname)
    @client.make_request("#{APIClient::API_PATH}/plugins")
  end

  class APIClient
    API_PATH = "/api/v2/account/clients"
    API_HOST = ENV["SCOUT_HOST"] || "http://server.pingdom.com"

    def initialize(account_key, hostname)
      @auth_params = { hostname: hostname, key: account_key }
    end

    def make_request(endpoint)
      uri = URI("#{API_HOST}#{endpoint}")
      uri.query = URI.encode_www_form(auth_params)

      json = nil
      response = Net::HTTP.get_response(uri)
      if response.is_a?(Net::HTTPSuccess)
        json = JSON.parse(response.body)
      else
        puts response.message
      end

      json
    end

    private

    attr_reader :auth_params

  end

end
