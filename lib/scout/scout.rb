require_relative "client"
require_relative "plugins"

require "fileutils"

class Scout
  HISTORY_FILE = "/var/lib/scoutd/client_history.yaml"

  class << self
    def deactivate
      system "scoutctl stop"
      system "mv -f #{HISTORY_FILE} #{HISTORY_FILE}.bak"
    end

    def download_plugins
      configuration = PSMClient.new.configuration
      Plugins::Downloader.new(configuration).call
    end
  end
end
