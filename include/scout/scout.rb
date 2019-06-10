require_relative "client"
require_relative "plugins"

require "fileutils"

class Scout
	class << self
		def deactivate
			system "scoutctl stop"
			system "mv -f /var/lib/scoutd/client_history.yaml /var/lib/scoutd/client_history.yaml.bak"
		end

		def download_plugins
			client_configuration = PSMClient.gather_facts
			Plugins::Downloader.new(client_configuration).call
		end
	end
end
