require "yaml"
require_relative "psm/api_client"

class PSMClient
	def self.gather_facts
		new.call
	end

	def initialize
		@hostname = `hostname`.chomp
	end

	def call
		client_roles = fetch_client_roles
		scout_configuration.merge!(client_roles)
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

		def fetch_client_roles
			roles = {}

			response = api_client.make_request("/api/v2/account/clients/roles")
			response.reject! {|r| r["name"] == "All Servers"}
			response.map! {|r| r["name"].gsub(/(\s+|\W+)/, "_")}

			roles.merge!({api_roles: response}) if response.any?

			roles
		end

		def api_client
			@client ||= Psm::ApiClient.new(account_key, hostname)
		end
end
