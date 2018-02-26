require 'yaml'
require_relative './psm/api_client'

class Client
  def self.gather_facts
    new.call
  end

  def initialize
    @hostname = `hostname`.chomp
  end

  def call
    unless scout_configuration["hostname"]
      scout_configuration.merge!({
        "hostname" => @hostname
      })
    end
    key_processes = fetch_key_processes
    scout_configuration.merge!(key_processes)
  end

  private

  def hostname
    scout_configuration["hostname"] || @hostname
  end

  def account_key
    scout_configuration["account_key"]
  end

  def config_file
    %(/etc/scout/scoutd.yml)
  end

  def scout_configuration
    @scout_configuration ||= YAML.load(File.read(config_file))
  end

  def fetch_key_processes
    client = Psm::ApiClient.new(account_key, hostname)
    response = client.make_request('/api/v2/account/clients/processes')
    { key_processes: response.map { |p| p["name"] } }
  end
end
