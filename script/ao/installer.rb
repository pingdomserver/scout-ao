module Ao
  class Installer
    HOST_AGENT_URL = %(https://files.appoptics.com/appoptics-host-agent-installer.sh)
    class << self
      def call(api_key)
        return if File.exists?(%(/opt/appoptics))

        system %(export APPOPTICS_INSTALL_ONLY=1)
        system %(bash -c "$(curl -sSL #{HOST_AGENT_URL})" -s --token #{api_key})
      end
    end
  end
end
