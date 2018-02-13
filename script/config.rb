require 'erb'
require 'pry'
require 'net/http'
require_relative './psm/api_client'

class Configuration
  def initialize(opts = {})
    opts.each do |k,v|
      instance_variable_set :"@#{k}", v
    end
    @erb_template = ERB.new(File.read(
      File.expand_path(
        "../../config/templates/config.yml.erb", __FILE__
    )))
    @key_processes = fetch_key_processes
  end

  def call
    puts @erb_template.result(binding)
  end

  attr_reader :account_key, :environment, :hostname, :roles, :key_processes

  def fetch_key_processes
    client = Psm::ApiClient.new(account_key, hostname)
    response = client.make_request("/api/v2/account/clients/processes")

    response.map do |process|
      process["name"]
    end
  end
end
