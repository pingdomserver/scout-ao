require "fileutils"

require_relative "client"
require_relative "plugins"

class Scout
  HISTORY_FILE = "/var/lib/scoutd/client_history.yaml"
  CONFIG_FILE = "/etc/scout/scoutd.yml"
  SCOUTD = "scoutd"

  class << self
    def running?
      system "pgrep #{SCOUTD}"
    end

    def deactivate
      scoutd_pid = %x(pgrep #{SCOUTD}).chomp
      system "scoutctl stop"
      system "[ -f #{HISTORY_FILE} ] && mv -f #{HISTORY_FILE} #{HISTORY_FILE}.bak"


      # Wait for scoutd children
      timeout = 15
      i = 0
      while system "pgrep -P #{scoutd_pid} >/dev/null" do

        # Kill eventually
        if i >= timeout
          %x(pgrep -P #{scoutd_pid}).lines.each do |pid|
            system "kill -9 #{pid}"
          end
        end

        i += 1
        sleep 1
      end
    end

    def download_plugins
      s = Scout.new
      Plugins::Downloader.new(s.account_key, s.hostname).call
    end

    # Fix scout-related permissions
    # (scout-client would be run under solarwinds user/group)
    def fix_permissions
      system "usermod -a -G scoutd solarwinds"
      system "chmod -v g+rw /var/log/scout/scoutd.log"
      system "chmod -Rv g+w /var/lib/scoutd"
    end
  end

  def initialize
    @scout_configuration ||= YAML.load(File.read(CONFIG_FILE))
    @hostname ||= hostname
  end

  def hostname
    @scout_configuration["hostname"] || %x(hostname).chomp
  end

  def account_key
    @scout_configuration["account_key"]
  end

  def configuration
    @scout_configuration.merge!(PSMClient.new(account_key, hostname).roles)
  end

  def environment
    @environment ||= PSMClient.new(account_key, hostname).environment || ENV["RACK_ENV"] || "production"
  end

  def roles
    @roles ||= PSMClient.new(account_key, hostname).roles
  end
end
