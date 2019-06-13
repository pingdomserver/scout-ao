require "yaml"
require "net/http"
require "json"
require "uri"

class PSMClient
  CONFIG_FILE = "/etc/scout/scoutd.yml"

  def initialize
    @scout_configuration ||= YAML.load(File.read(CONFIG_FILE))
    @hostname ||= hostname
  end

  def hostname
    @scout_configuration["hostname"] || `hostname`.chomp
  end

  def account_key
    @scout_configuration["account_key"]
  end

  def configuration
    @scout_configuration.merge!(roles)
  end

  def environment
    @environment ||= fetch_environment
  end

  def roles
    @roles ||= fetch_roles
  end

  def plugins
    @plugins ||= fetch_plugins
  end

  private

  def fetch_roles
    roles = {}

    @client ||= APIClient.new(account_key, hostname)
    response = @client.make_request("/api/v2/account/clients/roles")
    response.reject! { |r| r["name"] == "All Servers" }
    response.map! { |r| r["name"].gsub(/(\s+|\W+)/, "_") }

    roles.merge!({ api_roles: response }) if response.any?

    roles
  end

  def fetch_environment
    @client ||= APIClient.new(account_key, hostname)
    response = @client.make_request("/api/v2/account/clients/environment")

    response["name"]
  end

  def fetch_plugins
    @client ||= APIClient.new(account_key, hostname)
    @client.make_request("/api/v2/account/clients/plugins")
  end

  class APIClient
    API_HOST = ENV["SCOUT_HOST"] || "http://server.pingdom.com"

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
