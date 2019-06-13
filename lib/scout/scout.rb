require_relative "client"
require_relative "plugins"

require "fileutils"

class Scout
  HISTORY_FILE = "/var/lib/scoutd/client_history.yaml"

  class << self
    def deactivate
      system "scoutctl stop"
      system "[ -f #{HISTORY_FILE} ] && mv -f #{HISTORY_FILE} #{HISTORY_FILE}.bak"
    end

    def download_plugins
      configuration = PSMClient.new.configuration
      Plugins::Downloader.new(configuration).call
    end

    # Fix scout-related permissions
    # (scout-client would be ran under solarwinds user/group)
    def fix_permissions
      system "usermod -a -G scoutd solarwinds"
      system "chmod -v g+rw /var/log/scout/scoutd.log"
      system "chmod -Rv g+w /var/lib/scoutd"
    end
  end
end
