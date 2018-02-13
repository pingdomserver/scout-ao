require 'erb'
require 'pry'
require 'net/http'

class Configuration
  API_ENDPOINT = %(/api/v2/account/clients/processes)
  API_HOST = %(http://localhost:3000)

  def initialize(opts = {})
    opts.each do |k,v|
      instance_variable_set :"@#{k}", v
    end
    @erb_template = ERB.new(File.read(
      File.expand_path(
        "../../config/templates/config.yml.erb", __FILE__
    )))
    @key_processes = []
  end

  def call
    fetch_key_processes

    puts @erb_template.result(binding)
  end

  attr_reader :account_key, :environment, :hostname, :roles, :key_processes

  def fetch_key_processes
    uri = URI("#{API_HOST}#{API_ENDPOINT}")
    params = { hostname: hostname, key: account_key }
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.get_response(uri)
    parsed_response = JSON.parse(response.body)
    @key_processes = parsed_response.map do |process|
      process["name"]
    end
  end
end
